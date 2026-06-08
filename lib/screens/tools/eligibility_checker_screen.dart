import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  bool _profileLoaded   = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  final List<String> _categories     = ['General', 'OBC', 'SC', 'ST', 'EWS', 'Ex-Serviceman'];
  final List<String> _qualifications = [
    '8th Pass',
    '10th Pass (Matric)',
    '12th Pass (Inter)',
    'ITI',
    'Diploma (Engineering)',
    'Diploma (Non-Engineering)',
    // Graduate
    'B.A (Arts)',
    'B.Sc (Science)',
    'B.Com (Commerce)',
    'B.Tech / B.E (Engineering)',
    'B.C.A (Computer)',
    'B.B.A (Business)',
    'B.Ed (Teaching)',
    'B.Sc Nursing',
    'B.Pharma',
    'B.Sc Agriculture',
    'BDS (Dental)',
    'MBBS (Medical)',
    'LLB (Law)',
    'B.Arch (Architecture)',
    'B.Sc (IT)',
    'Other Graduate',
    // Post Graduate
    'M.A (Arts)',
    'M.Sc (Science)',
    'M.Com (Commerce)',
    'M.Tech / M.E (Engineering)',
    'M.C.A (Computer)',
    'M.B.A (Business)',
    'M.Ed (Teaching)',
    'M.Sc Nursing',
    'M.Pharma',
    'LLM (Law)',
    'PGDM',
    'Other Post Graduate',
    'Ph.D',
  ];
  final List<String> _genders        = ['Male', 'Female', 'Transgender'];
  final List<String> _states         = ['Punjab', 'Haryana', 'Himachal Pradesh', 'Delhi', 'Uttar Pradesh', 'Rajasthan', 'Bihar', 'Uttarakhand'];

  final List<Map<String, dynamic>> _exams = [
    {
      'id': 'ssc_cgl',
      'name': 'SSC CGL 2026',
      'org': 'Staff Selection Commission',
      'category': 'SSC',
      'color': Color(0xFFE65100),
      'icon': Icons.description,
      'minAge': {'General': 18, 'OBC': 18, 'SC': 18, 'ST': 18, 'EWS': 18, 'Ex-Serviceman': 18},
      'maxAge': {'General': 32, 'OBC': 35, 'SC': 37, 'ST': 37, 'EWS': 32, 'Ex-Serviceman': 32},
      'qualifications': ['Graduate', 'Post Graduate', 'LLB', 'MBBS'],
      'genders': ['Male', 'Female', 'Transgender'],
      'allIndia': true,
      'vacancies': 12256,
      'salary': '25,500 - 1,42,400',
      'physicalRequired': false,
      'details': 'Combined Graduate Level exam for Group B & C posts',
    },
    {
      'id': 'rrb_ntpc',
      'name': 'RRB NTPC 2026',
      'org': 'Railway Recruitment Board',
      'category': 'Railway',
      'color': Color(0xFF1565C0),
      'icon': Icons.train,
      'minAge': {'General': 18, 'OBC': 18, 'SC': 18, 'ST': 18, 'EWS': 18, 'Ex-Serviceman': 18},
      'maxAge': {'General': 33, 'OBC': 36, 'SC': 38, 'ST': 38, 'EWS': 33, 'Ex-Serviceman': 33},
      'qualifications': ['12th Pass', 'Diploma', 'Graduate', 'Post Graduate', 'B.Ed', 'B.Sc Nursing', 'LLB', 'MBBS'],
      'genders': ['Male', 'Female', 'Transgender'],
      'allIndia': true,
      'vacancies': 8868,
      'salary': '19,900 - 35,400',
      'physicalRequired': false,
      'details': 'Non-Technical Popular Category posts across all railway zones',
    },
    {
      'id': 'punjab_police',
      'name': 'Punjab Police Constable',
      'org': 'Punjab Police Dept.',
      'category': 'Police',
      'color': Color(0xFF1B5E20),
      'icon': Icons.local_police,
      'minAge': {'General': 18, 'OBC': 18, 'SC': 18, 'ST': 18, 'EWS': 18, 'Ex-Serviceman': 18},
      'maxAge': {'General': 28, 'OBC': 31, 'SC': 33, 'ST': 33, 'EWS': 28, 'Ex-Serviceman': 35},
      'qualifications': ['12th Pass', 'Diploma', 'Graduate', 'Post Graduate', 'B.Ed', 'B.Sc Nursing', 'LLB', 'MBBS'],
      'genders': ['Male', 'Female', 'Transgender'],
      'allIndia': false,
      'statesAllowed': ['Punjab'],
      'vacancies': 3298,
      'salary': '19,900 - 63,200',
      'physicalRequired': true,
      'physicalStandards': {
        'Male':   {'height': 167.6, 'chest': '81-86 cm', 'run': '1600m in 6.5 min'},
        'Female': {'height': 157.5, 'chest': 'N/A',      'run': '800m in 4 min'},
      },
      'details': 'Punjab state police constable recruitment',
    },
    {
      'id': 'ibps_po',
      'name': 'IBPS PO 2026',
      'org': 'Institute of Banking Personnel',
      'category': 'Banking',
      'color': Color(0xFF6A1B9A),
      'icon': Icons.account_balance,
      'minAge': {'General': 20, 'OBC': 20, 'SC': 20, 'ST': 20, 'EWS': 20, 'Ex-Serviceman': 20},
      'maxAge': {'General': 30, 'OBC': 33, 'SC': 35, 'ST': 35, 'EWS': 30, 'Ex-Serviceman': 30},
      'qualifications': ['Graduate', 'Post Graduate', 'B.Ed', 'B.Sc Nursing', 'LLB', 'MBBS'],
      'genders': ['Male', 'Female', 'Transgender'],
      'allIndia': true,
      'vacancies': 4000,
      'salary': '65,000 - 85,000',
      'physicalRequired': false,
      'details': 'Probationary Officer in Public Sector Banks',
    },
    {
      'id': 'army_gd',
      'name': 'Indian Army Agniveer 2026',
      'org': 'Indian Army',
      'category': 'Army',
      'color': Color(0xFF33691E),
      'icon': Icons.military_tech,
      'minAge': {'General': 17, 'OBC': 17, 'SC': 17, 'ST': 17, 'EWS': 17, 'Ex-Serviceman': 17},
      'maxAge': {'General': 21, 'OBC': 21, 'SC': 21, 'ST': 21, 'EWS': 21, 'Ex-Serviceman': 21},
      'qualifications': ['10th Pass', '12th Pass', 'Diploma', 'Graduate', 'Post Graduate', 'B.Ed', 'B.Sc Nursing', 'LLB', 'MBBS'],
      'genders': ['Male'],
      'allIndia': true,
      'vacancies': 25000,
      'salary': '30,000 - 40,000',
      'physicalRequired': true,
      'physicalStandards': {
        'Male': {'height': 160.0, 'chest': '77-82 cm', 'run': '1600m in 5.30 min'},
      },
      'details': 'Agniveer recruitment under Agnipath scheme (Male only)',
    },
    {
      'id': 'upsc_cse',
      'name': 'UPSC CSE 2026',
      'org': 'Union Public Service Commission',
      'category': 'UPSC',
      'color': Color(0xFF880E4F),
      'icon': Icons.gavel,
      'minAge': {'General': 21, 'OBC': 21, 'SC': 21, 'ST': 21, 'EWS': 21, 'Ex-Serviceman': 21},
      'maxAge': {'General': 32, 'OBC': 35, 'SC': 37, 'ST': 37, 'EWS': 32, 'Ex-Serviceman': 37},
      'qualifications': ['Graduate', 'Post Graduate', 'B.Ed', 'B.Sc Nursing', 'LLB', 'MBBS'],
      'genders': ['Male', 'Female', 'Transgender'],
      'allIndia': true,
      'vacancies': 933,
      'salary': '56,100 - 2,50,000',
      'physicalRequired': false,
      'details': 'Civil Services for IAS, IPS, IFS and allied services',
    },
    {
      'id': 'ssc_chsl',
      'name': 'SSC CHSL 2026',
      'org': 'Staff Selection Commission',
      'category': 'SSC',
      'color': Color(0xFFE65100),
      'icon': Icons.description,
      'minAge': {'General': 18, 'OBC': 18, 'SC': 18, 'ST': 18, 'EWS': 18, 'Ex-Serviceman': 18},
      'maxAge': {'General': 27, 'OBC': 30, 'SC': 32, 'ST': 32, 'EWS': 27, 'Ex-Serviceman': 27},
      'qualifications': ['12th Pass', 'Diploma', 'Graduate', 'Post Graduate', 'B.Ed', 'B.Sc Nursing', 'LLB', 'MBBS'],
      'genders': ['Male', 'Female', 'Transgender'],
      'allIndia': true,
      'vacancies': 3712,
      'salary': '18,000 - 56,900',
      'physicalRequired': false,
      'details': 'Combined Higher Secondary Level for LDC, JSA, PA, DEO posts',
    },
    {
      'id': 'psssb_clerk',
      'name': 'PSSSB Clerk 2026',
      'org': 'Punjab Subordinate Services Board',
      'category': 'SSC',
      'color': Color(0xFFE65100),
      'icon': Icons.edit_document,
      'minAge': {'General': 18, 'OBC': 18, 'SC': 18, 'ST': 18, 'EWS': 18, 'Ex-Serviceman': 18},
      'maxAge': {'General': 37, 'OBC': 40, 'SC': 42, 'ST': 42, 'EWS': 37, 'Ex-Serviceman': 42},
      'qualifications': ['Graduate', 'Post Graduate', 'B.Ed', 'B.Sc Nursing', 'LLB', 'MBBS'],
      'genders': ['Male', 'Female', 'Transgender'],
      'allIndia': false,
      'statesAllowed': ['Punjab'],
      'vacancies': 1152,
      'salary': '10,300 - 34,800',
      'physicalRequired': false,
      'details': 'Clerk posts in Punjab Government departments',
    },
    {
      'id': 'teaching',
      'name': 'Punjab Teaching 2026',
      'org': 'Dept. of School Education Punjab',
      'category': 'Teaching',
      'color': Color(0xFF0277BD),
      'icon': Icons.school,
      'minAge': {'General': 18, 'OBC': 18, 'SC': 18, 'ST': 18, 'EWS': 18, 'Ex-Serviceman': 18},
      'maxAge': {'General': 37, 'OBC': 40, 'SC': 42, 'ST': 42, 'EWS': 37, 'Ex-Serviceman': 42},
      'qualifications': ['B.Ed'],
      'genders': ['Male', 'Female', 'Transgender'],
      'allIndia': false,
      'statesAllowed': ['Punjab'],
      'vacancies': 8393,
      'salary': '29,200 - 92,300',
      'physicalRequired': false,
      'details': 'Government school teachers in Punjab (B.Ed required)',
    },
    {
      'id': 'nhm_nurse',
      'name': 'NHM Punjab Staff Nurse',
      'org': 'National Health Mission Punjab',
      'category': 'Health',
      'color': Color(0xFFC62828),
      'icon': Icons.local_hospital,
      'minAge': {'General': 18, 'OBC': 18, 'SC': 18, 'ST': 18, 'EWS': 18, 'Ex-Serviceman': 18},
      'maxAge': {'General': 37, 'OBC': 40, 'SC': 42, 'ST': 42, 'EWS': 37, 'Ex-Serviceman': 42},
      'qualifications': ['B.Sc Nursing'],
      'genders': ['Male', 'Female', 'Transgender'],
      'allIndia': false,
      'statesAllowed': ['Punjab'],
      'vacancies': 889,
      'salary': '25,000 - 45,000',
      'physicalRequired': false,
      'details': 'Staff Nurse in government health centers',
    },
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(
        parent: _animController, curve: Curves.easeOut);
    _loadUserProfile();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ── Auto load user profile from Firebase ──────────────
  Future<void> _loadUserProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data()!;

          // Load DOB
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

          // Load qualification — accept any valid qualification
          final qual = data['qualification'] as String?;
          if (qual != null) {
            // Map old values to new format if needed
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
            final mappedQual = legacyMap[qual] ?? qual;
            setState(() => _qualification = mappedQual);
          }

          // Load state
          final state = data['state'] as String?;
          if (state != null && _states.contains(state)) {
            setState(() => _state = state);
          }

          // Load gender
          final gender = data['gender'] as String?;
          if (gender != null &&
              _genders.contains(gender)) {
            setState(() => _gender = gender);
          }

          setState(() => _profileLoaded = true);
        }
      }
    } catch (e) {
      print('Error loading profile: $e');
    }
    setState(() => _isLoadingProfile = false);
  }

  int get _ageYears {
    if (_dob == null) return 0;
    final today = DateTime.now();
    int age = today.year - _dob!.year;
    if (today.month < _dob!.month ||
        (today.month == _dob!.month &&
            today.day < _dob!.day)) age--;
    return age;
  }

  // Graduate/PostGrad sub-options
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

  void _showQualificationPicker() {
    String? expandedGroup;
    final simpleOptions = _qualifications.where((q) =>
        !_graduateOptions.contains(q) &&
        !_postGraduateOptions.contains(q) &&
        q != 'Ph.D').toList();

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
          child: Column(
            children: [
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
                        fontSize: 18, fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A2E))),
              ),
              const Divider(height: 1),
              Expanded(child: ListView(children: [
                ...simpleOptions.map((q) => _qualItem(q, setSheetState)),
                // Graduate group
                _qualHeader('Graduate', Icons.school_outlined,
                    expandedGroup == 'grad',
                    _graduateOptions.contains(_qualification),
                    () => setSheetState(() =>
                        expandedGroup = expandedGroup == 'grad' ? null : 'grad')),
                if (expandedGroup == 'grad')
                  ..._graduateOptions.map((q) => _qualItem(q, setSheetState, sub: true)),
                // Post Graduate group
                _qualHeader('Post Graduate', Icons.workspace_premium_outlined,
                    expandedGroup == 'pg',
                    _postGraduateOptions.contains(_qualification),
                    () => setSheetState(() =>
                        expandedGroup = expandedGroup == 'pg' ? null : 'pg')),
                if (expandedGroup == 'pg')
                  ..._postGraduateOptions.map((q) => _qualItem(q, setSheetState, sub: true)),
                _qualItem('Ph.D', setSheetState),
                const SizedBox(height: 20),
              ])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _qualItem(String q, StateSetter setSheetState, {bool sub = false}) {
    final sel = _qualification == q;
    return InkWell(
      onTap: () {
        setState(() => _qualification = q);
        Navigator.pop(context);
      },
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

  Widget _qualHeader(String label, IconData icon, bool expanded,
      bool selected, VoidCallback onTap) {
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

  int _qualRank(String q) {
    // Map all qualifications to their rank level
    // Rank 0=8th, 1=10th, 2=12th, 3=Diploma/ITI, 4=Graduate, 5=PostGrad, 6=PhD
    const Map<String, int> rankMap = {
      '8th Pass': 0,
      '10th Pass': 1, '10th Pass (Matric)': 1,
      '12th Pass': 2, '12th Pass (Inter)': 2,
      'ITI': 3,
      'Diploma': 3, 'Diploma (Engineering)': 3, 'Diploma (Non-Engineering)': 3,
      // Graduate level
      'Graduate': 4,
      'B.A (Arts)': 4, 'B.Sc (Science)': 4, 'B.Com (Commerce)': 4,
      'B.Tech / B.E (Engineering)': 4, 'B.C.A (Computer)': 4,
      'B.B.A (Business)': 4, 'B.Ed (Teaching)': 4, 'B.Ed': 4,
      'B.Sc Nursing': 4, 'B.Pharma': 4, 'B.Sc Agriculture': 4,
      'BDS (Dental)': 4, 'MBBS (Medical)': 4, 'MBBS': 4,
      'LLB (Law)': 4, 'LLB': 4,
      'B.Arch (Architecture)': 4, 'B.Sc (IT)': 4,
      'Other Graduate': 4,
      // Post Graduate level
      'Post Graduate': 5,
      'M.A (Arts)': 5, 'M.Sc (Science)': 5, 'M.Com (Commerce)': 5,
      'M.Tech / M.E (Engineering)': 5, 'M.C.A (Computer)': 5,
      'M.B.A (Business)': 5, 'M.Ed (Teaching)': 5, 'M.Sc Nursing': 5,
      'M.Pharma': 5, 'LLM (Law)': 5, 'PGDM': 5,
      'Other Post Graduate': 5,
      'Ph.D': 6,
    };
    return rankMap[q] ?? 0;
  }

  Map<String, dynamic> _checkExam(
      Map<String, dynamic> exam) {
    List<String> fails  = [];
    List<String> passes = [];
    int age = _ageYears;

    final minAge =
    (exam['minAge'] as Map)[_category] as int;
    final maxAge =
    (exam['maxAge'] as Map)[_category] as int;

    if (age < minAge) {
      fails.add(
          'Too young — min age is $minAge for $_category');
    } else if (age > maxAge) {
      fails.add(
          'Age exceeded — max is $maxAge for $_category');
    } else {
      passes.add(
          'Age $age years is OK (limit: $minAge-$maxAge)');
    }

    final reqQuals =
    exam['qualifications'] as List<String>;
    final userRank = _qualRank(_qualification);
    final meetsQual =
    reqQuals.any((q) => _qualRank(q) <= userRank);
    if (!meetsQual) {
      fails.add(
          'Need ${reqQuals.first} minimum (you have $_qualification)');
    } else {
      passes.add('Qualification $_qualification is OK');
    }

    final allowedGenders = exam['genders'] as List<String>;
    if (!allowedGenders.contains(_gender)) {
      fails.add('Not open for $_gender candidates');
    } else {
      passes.add('Gender $_gender is accepted');
    }

    if (exam['allIndia'] != true) {
      final allowed =
      exam['statesAllowed'] as List<String>;
      if (!allowed.contains(_state)) {
        fails.add(
            'Only for ${allowed.join(', ')} residents');
      } else {
        passes.add('State $_state is eligible');
      }
    } else {
      passes.add('Open for all India candidates');
    }

    if (exam['physicalRequired'] == true &&
        _showPhysical) {
      final standards =
      (exam['physicalStandards'] as Map)[_gender];
      if (standards != null) {
        final minH = standards['height'] as double;
        if (_height < minH) {
          fails.add(
              'Height ${_height.toStringAsFixed(0)}cm is less than required ${minH.toStringAsFixed(0)}cm');
        } else {
          passes.add(
              'Height ${_height.toStringAsFixed(0)}cm is OK');
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

  @override
  Widget build(BuildContext context) {
    final eligible   = _hasChecked
        ? _exams
        .where((e) => _checkExam(e)['eligible'] == true)
        .toList()
        : <Map<String, dynamic>>[];
    final ineligible = _hasChecked
        ? _exams
        .where(
            (e) => _checkExam(e)['eligible'] == false)
        .toList()
        : <Map<String, dynamic>>[];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoadingProfile
                ? const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF1565C0)))
                : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  16, 16, 16, 80),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  // Pre-filled banner
                  if (_profileLoaded)
                    Container(
                      margin: const EdgeInsets.only(
                          bottom: 12),
                      padding:
                      const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981)
                            .withOpacity(0.1),
                        borderRadius:
                        BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(
                                0xFF10B981)
                                .withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                              Icons.check_circle,
                              color:
                              Color(0xFF10B981),
                              size: 16),
                          const SizedBox(width: 8),
                          Text(
                            '✅ Profile auto-filled from your account!',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: const Color(
                                    0xFF10B981)),
                          ),
                        ],
                      ),
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
                    _buildResultsSummary(
                        eligible.length,
                        ineligible.length),
                    const SizedBox(height: 16),
                    if (eligible.isNotEmpty) ...[
                      _sectionTitle(
                          'Eligible Exams',
                          const Color(0xFF10B981),
                          eligible.length),
                      const SizedBox(height: 10),
                      ...eligible.map((e) =>
                          _buildExamCard(e, true)),
                    ],
                    if (ineligible.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _sectionTitle(
                          'Not Eligible',
                          const Color(0xFFEF4444),
                          ineligible.length),
                      const SizedBox(height: 10),
                      ...ineligible.map((e) =>
                          _buildExamCard(e, false)),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16, right: 16, bottom: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pushReplacementNamed(
                    context, '/home'),
                child: const Icon(Icons.arrow_back,
                    color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text('Eligibility Checker',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${_exams.length} Exams',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
              'Fill your details to see which exams you qualify for',
              style: GoogleFonts.poppins(
                  color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF90CAF9)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline,
              color: Color(0xFF1565C0), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Age relaxation auto-applied: OBC +3 yrs, SC/ST +5 yrs, Ex-Serviceman +3 to +5 yrs',
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF1565C0)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10)
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Personal Details',
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A2E))),
          const SizedBox(height: 14),

          // DOB Picker
          GestureDetector(
            onTap: _pickDOB,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(
                    color: const Color(0xFFD1D5DB)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cake_outlined,
                      color: Color(0xFF6B7280), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _dob == null
                          ? 'Select your Date of Birth'
                          : 'DOB: ${_dob!.day.toString().padLeft(2, '0')}/${_dob!.month.toString().padLeft(2, '0')}/${_dob!.year}   →   Age: $_ageYears years',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: _dob == null
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF1A1A2E),
                      ),
                    ),
                  ),
                  const Icon(Icons.edit_calendar_outlined,
                      color: Color(0xFF9CA3AF), size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Gender
          Text('Gender',
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF374151))),
          const SizedBox(height: 8),
          Row(
            children: _genders.map((g) {
              final sel = _gender == g;
              return Expanded(
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _gender = g),
                  child: AnimatedContainer(
                    duration:
                    const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        vertical: 10),
                    decoration: BoxDecoration(
                      color: sel
                          ? const Color(0xFF1565C0)
                          : Colors.white,
                      borderRadius:
                      BorderRadius.circular(10),
                      border: Border.all(
                          color: sel
                              ? const Color(0xFF1565C0)
                              : const Color(0xFFD1D5DB)),
                    ),
                    child: Text(g,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: sel
                            ? Colors.white
                            : const Color(0xFF374151),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Category
          Text('Category',
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF374151))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _categories.map((c) {
              final sel = _category == c;
              return GestureDetector(
                onTap: () =>
                    setState(() => _category = c),
                child: AnimatedContainer(
                  duration:
                  const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel
                        ? const Color(0xFF1565C0)
                        : Colors.white,
                    borderRadius:
                    BorderRadius.circular(20),
                    border: Border.all(
                        color: sel
                            ? const Color(0xFF1565C0)
                            : const Color(0xFFD1D5DB)),
                  ),
                  child: Text(c,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: sel
                          ? Colors.white
                          : const Color(0xFF374151),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),
          const Divider(
              height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 20),

          Text('Education & Location',
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A2E))),
          const SizedBox(height: 14),

          // Qualification
          GestureDetector(
            onTap: () => _showQualificationPicker(),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD1D5DB)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Highest Qualification',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: const Color(0xFF6B7280))),
                        const SizedBox(height: 2),
                        Text(_qualification,
                            style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: const Color(0xFF1A1A2E))),
                      ],
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down,
                      color: Color(0xFF6B7280)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // State
          DropdownButtonFormField<String>(
            value: _state,
            decoration: InputDecoration(
              labelText: 'Your State',
              labelStyle: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF6B7280)),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
            ),
            style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFF1A1A2E)),
            items: _states
                .map((s) => DropdownMenuItem(
                value: s, child: Text(s)))
                .toList(),
            onChanged: (v) =>
                setState(() => _state = v!),
          ),
        ],
      ),
    );
  }

  Widget _buildPhysicalToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8)
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B5E20)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.fitness_center,
                    color: Color(0xFF1B5E20), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text('Include Physical Standards',
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color:
                            const Color(0xFF1A1A2E))),
                    Text('For Police and Army exams',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color:
                            const Color(0xFF6B7280))),
                  ],
                ),
              ),
              Switch(
                value: _showPhysical,
                onChanged: (v) =>
                    setState(() => _showPhysical = v),
                activeColor: const Color(0xFF1565C0),
              ),
            ],
          ),
          if (_showPhysical) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
                'Your Height: ${_height.toStringAsFixed(0)} cm',
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            Slider(
              value: _height,
              min: 140, max: 200, divisions: 60,
              activeColor: const Color(0xFF1565C0),
              label: '${_height.toStringAsFixed(0)} cm',
              onChanged: (v) =>
                  setState(() => _height = v),
            ),
            Text(
                'Your Weight: ${_weight.toStringAsFixed(0)} kg',
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            Slider(
              value: _weight,
              min: 40, max: 120, divisions: 80,
              activeColor: const Color(0xFF1565C0),
              label: '${_weight.toStringAsFixed(0)} kg',
              onChanged: (v) =>
                  setState(() => _weight = v),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCheckButton() {
    final canCheck = _dob != null;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: canCheck ? _runCheck : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1565C0),
          disabledBackgroundColor:
          const Color(0xFFD1D5DB),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: canCheck ? 4 : 0,
        ),
        child: Text(
          canCheck
              ? 'Check My Eligibility'
              : 'Select DOB to Continue',
          style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildResultsSummary(
      int eligCount, int notEligCount) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _summaryItem('$eligCount', 'Eligible',
                const Color(0xFF10B981)),
            Container(
                width: 1, height: 50,
                color: Colors.white24),
            _summaryItem('$notEligCount', 'Not Eligible',
                const Color(0xFFEF4444)),
            Container(
                width: 1, height: 50,
                color: Colors.white24),
            _summaryItem('${_exams.length}', 'Total Exams',
                Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(
      String value, String label, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 26,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: GoogleFonts.poppins(
                color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _buildExamCard(
      Map<String, dynamic> exam, bool eligible) {
    final catColor = exam['color'] as Color;
    final result   = _checkExam(exam);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: eligible
              ? const Color(0xFF10B981).withOpacity(0.3)
              : const Color(0xFFEF4444).withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8)
        ],
      ),
      child: Theme(
        data: Theme.of(context)
            .copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 4),
          childrenPadding:
          const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
                color: catColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(exam['icon'] as IconData,
                color: catColor, size: 20),
          ),
          title: Text(exam['name'] as String,
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1A2E))),
          subtitle: Text(exam['org'] as String,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF6B7280))),
          trailing: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: eligible
                  ? const Color(0xFF10B981)
                  .withOpacity(0.1)
                  : const Color(0xFFEF4444)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              eligible ? '✓ Eligible' : '✗ Not Eligible',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: eligible
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
              ),
            ),
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius:
                  BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(exam['details'] as String,
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color:
                          const Color(0xFF6B7280))),
                  const SizedBox(height: 10),
                  Row(children: [
                    const Icon(Icons.people_outline,
                        size: 13,
                        color: Color(0xFF9CA3AF)),
                    const SizedBox(width: 4),
                    Text('${exam['vacancies']} Posts',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(
                                0xFF374151))),
                    const SizedBox(width: 16),
                    const Icon(Icons.currency_rupee,
                        size: 13,
                        color: Color(0xFF9CA3AF)),
                    const SizedBox(width: 4),
                    Text(exam['salary'] as String,
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(
                                0xFF374151))),
                  ]),
                  const SizedBox(height: 10),
                  ...(result['passes'] as List<String>)
                      .map((p) => _checkRow(p, true)),
                  if ((result['fails'] as List)
                      .isNotEmpty) ...[
                    const SizedBox(height: 4),
                    ...(result['fails'] as List<String>)
                        .map((f) => _checkRow(f, false)),
                  ],
                  if (exam['physicalRequired'] ==
                      true) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B5E20)
                            .withOpacity(0.05),
                        borderRadius:
                        BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFF1B5E20)
                                .withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                              'Physical Standards ($_gender)',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight:
                                  FontWeight.w600,
                                  color: const Color(
                                      0xFF1B5E20))),
                          const SizedBox(height: 6),
                          if ((exam['physicalStandards']
                          as Map)
                              .containsKey(_gender))
                            ...(exam['physicalStandards']
                            as Map)[_gender]
                                .entries
                                .map<Widget>((e) =>
                                Padding(
                                  padding:
                                  const EdgeInsets
                                      .only(
                                      bottom: 3),
                                  child: Text(
                                      '${e.key}: ${e.value}',
                                      style: GoogleFonts
                                          .poppins(
                                          fontSize:
                                          12,
                                          color: const Color(
                                              0xFF374151))),
                                )),
                          if (!(exam['physicalStandards']
                          as Map)
                              .containsKey(_gender))
                            Text(
                                'Not open for $_gender candidates',
                                style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: const Color(
                                        0xFFEF4444))),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _checkRow(String text, bool pass) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            pass
                ? Icons.check_circle_outline
                : Icons.cancel_outlined,
            size: 15,
            color: pass
                ? const Color(0xFF10B981)
                : const Color(0xFFEF4444),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: pass
                        ? const Color(0xFF374151)
                        : const Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(
      String title, Color color, int count) {
    return Row(
      children: [
        Text(title,
            style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A2E))),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20)),
          child: Text('$count',
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ),
      ],
    );
  }

  Future<void> _pickDOB() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1998),
      firstDate: DateTime(1980),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
                primary: Color(0xFF1565C0))),
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
      selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle:
      GoogleFonts.poppins(fontSize: 11),
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