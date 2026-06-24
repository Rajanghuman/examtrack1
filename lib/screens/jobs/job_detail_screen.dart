import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../l10n/language_provider.dart';
import '../../l10n/app_strings.dart';

class JobDetailScreen extends StatefulWidget {
  const JobDetailScreen({super.key});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSaved    = false;
  bool _isApplied  = false;
  String _userQualification = '';
  String _userState = '';
  List<String> _userCategories = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          if (!mounted) return;
          setState(() {
            _userQualification = data['qualification'] as String? ?? '';
            _userState = data['state'] as String? ?? '';
            final cats = data['preferredExams']
                ?? data['categories']
                ?? data['preferredCategories'] ?? [];
            _userCategories = List<String>.from(cats);
          });
        }
      }
    } catch (e) {}
  }

  int _calculateMatchScore(Map<String, dynamic> job) {
    if (_userQualification.isEmpty && _userState.isEmpty) return 0;
    int score = 0;
    int total = 0;

    total += 40;
    final jobQual  = job['qualification'] as String? ?? '';
    final userRank = _qualRank(_userQualification);
    final jobRank  = _qualRank(jobQual);
    if (jobRank != -1 && userRank >= jobRank) score += 40;
    else if (jobRank != -1 && userRank == jobRank - 1) score += 20;

    total += 30;
    final jobState = job['state'] as String? ?? '';
    if (jobState == 'All India') score += 30;
    else if (jobState == _userState) score += 30;
    else if (_userState.isEmpty) score += 15;

    total += 20;
    final jobCat = job['category'] as String? ?? '';
    if (_userCategories.contains(jobCat)) score += 20;
    else if (_userCategories.isEmpty) score += 10;

    total += 10;
    final lastDate = job['lastDate'] as String? ?? '';
    if (lastDate.isNotEmpty &&
        !lastDate.toUpperCase().contains('CLOSED')) score += 10;

    return total > 0 ? ((score / total) * 100).round() : 0;
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
      'B.B.A (Business)': 4, 'B.Ed (Teaching)': 4,
      'B.Sc Nursing': 4, 'B.Pharma': 4, 'MBBS (Medical)': 4,
      'LLB (Law)': 4, 'B.Sc (IT)': 4,
      'Post Graduate': 5, 'Other Post Graduate': 5,
      'M.Tech / M.E (Engineering)': 5, 'M.B.A (Business)': 5,
      'Ph.D': 6,
    };
    return rankMap[q] ?? -1;
  }

  Color _matchScoreColor(int score) {
    if (score >= 80) return const Color(0xFF10B981);
    if (score >= 60) return const Color(0xFF1565C0);
    if (score >= 40) return const Color(0xFFF59E0B);
    return const Color(0xFF9CA3AF);
  }

  String _matchScoreLabel(int score) {
    if (score >= 80) return 'Excellent Match';
    if (score >= 60) return 'Good Match';
    if (score >= 40) return 'Fair Match';
    return 'Low Match';
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showToast(BuildContext context, String message,
      {bool success = true}) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      builder: (ctx) {
        Future.delayed(const Duration(seconds: 2), () {
          if (ctx.mounted) Navigator.pop(ctx);
        });
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 80),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: success
                      ? const Color(0xFF1A1A2E)
                      : const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8))
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      success
                          ? Icons.check_circle_rounded
                          : Icons.error_rounded,
                      color: success
                          ? const Color(0xFF10B981)
                          : Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(message,
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
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

  String _getOfficialWebsite(String category, String title) {
    final t = title.toLowerCase();
    if (t.contains('rrb') || t.contains('railway') ||
        t.contains('ntpc') || t.contains('alp') ||
        t.contains('group d') || t.contains('technician') ||
        category == 'Railway') {
      return 'https://www.rrbcdg.gov.in';
    } else if (t.contains('ssc') || category == 'SSC') {
      return 'https://ssc.gov.in';
    } else if (t.contains('ibps')) {
      return 'https://www.ibps.in';
    } else if (t.contains('sbi')) {
      return 'https://bank.sbi/careers';
    } else if (category == 'Banking') {
      return 'https://www.ibps.in';
    } else if (t.contains('punjab') && t.contains('police')) {
      return 'https://punjabpolice.gov.in';
    } else if (t.contains('psssb') || t.contains('punjab subordinate')) {
      return 'https://sssb.punjab.gov.in';
    } else if (category == 'Police') {
      return 'https://punjabpolice.gov.in';
    } else if (t.contains('army') || t.contains('agniveer') ||
        t.contains('soldier')) {
      return 'https://joinindianarmy.nic.in';
    } else if (t.contains('bro') || t.contains('border roads')) {
      return 'https://bro.gov.in';
    } else if (category == 'Army') {
      return 'https://joinindianarmy.nic.in';
    } else if (t.contains('upsc') || t.contains('ias') ||
        t.contains('ips') || t.contains('cds') || category == 'UPSC') {
      return 'https://upsconline.nic.in';
    } else if (t.contains('ctet')) {
      return 'https://ctet.nic.in';
    } else if (t.contains('teaching') || t.contains('teacher') ||
        t.contains('punjab') || category == 'Teaching') {
      return 'https://educationrecruitmentboard.com';
    } else if (t.contains('nhm') || t.contains('nurse') ||
        t.contains('health') || category == 'Health') {
      return 'https://nhm.punjab.gov.in';
    } else {
      return 'https://ncs.gov.in';
    }
  }


  Future<void> _openURL(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final lang = context.read<LanguageProvider>().languageCode;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showToast(context, AppStrings.get('could_not_open_link', lang), success: false);
    }
  }

  Future<void> _saveJob(String jobId, String title) async {
    final lang = context.read<LanguageProvider>().languageCode;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showToast(context, AppStrings.get('login_to_save', lang), success: false);
        return;
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'savedJobs': FieldValue.arrayUnion([jobId]),
      }, SetOptions(merge: true));
      if (!mounted) return;
      setState(() => _isSaved = true);
      _showToast(context, '$title ${AppStrings.get('job_saved_toast', lang)}');
    } catch (e) {
      _showToast(context, AppStrings.get('save_error_toast', lang), success: false);
    }
  }

  Future<void> _markAsApplied({
    required String jobId,
    required String title,
    required String organization,
    required String category,
    required String regNo,
    required String notes,
    required String userCategory,
  }) async {
    final lang = context.read<LanguageProvider>().languageCode;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final appliedDate =
          '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'appliedJobs': FieldValue.arrayUnion([title]),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'trackedJobs': FieldValue.arrayUnion([title]),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('trackedJobs')
          .add({
        'jobId':          jobId,
        'title':          title,
        'organization':   organization,
        'category':       category,
        'registrationNo': regNo,
        'notes':          notes,
        'status':         'Applied',
        'appliedDate':    appliedDate,
        'examDate':       'TBA',
        'userCategory':   userCategory,
        'marksObtained':  0,
        'addedAt':        FieldValue.serverTimestamp(),
        'stages':         _defaultStages(category),
      });

      if (!mounted) return;
      setState(() => _isApplied = true);
      _showToast(context, AppStrings.get('marked_applied_toast', lang));
    } catch (e) {
      _showToast(context, AppStrings.get('generic_error_toast', lang), success: false);
    }
  }

  List<Map<String, dynamic>> _defaultStages(String category) {
    switch (category) {
      case 'Railway':
        return [
          {'name': 'Application', 'done': true,  'date': ''},
          {'name': 'CBT Stage 1', 'done': false, 'date': 'TBA'},
          {'name': 'CBT Stage 2', 'done': false, 'date': 'TBA'},
          {'name': 'Document Verification', 'done': false, 'date': 'TBA'},
        ];
      case 'Police':
        return [
          {'name': 'Application',          'done': true,  'date': ''},
          {'name': 'Written Test',          'done': false, 'date': 'TBA'},
          {'name': 'Physical Test',         'done': false, 'date': 'TBA'},
          {'name': 'Medical Test',          'done': false, 'date': 'TBA'},
          {'name': 'Document Verification', 'done': false, 'date': 'TBA'},
        ];
      case 'Banking':
        return [
          {'name': 'Application',          'done': true,  'date': ''},
          {'name': 'Prelims',              'done': false, 'date': 'TBA'},
          {'name': 'Mains',               'done': false, 'date': 'TBA'},
          {'name': 'Interview',           'done': false, 'date': 'TBA'},
          {'name': 'Document Verification','done': false, 'date': 'TBA'},
        ];
      case 'Army':
        return [
          {'name': 'Application',          'done': true,  'date': ''},
          {'name': 'Physical Test',        'done': false, 'date': 'TBA'},
          {'name': 'Written Test',         'done': false, 'date': 'TBA'},
          {'name': 'Medical Test',         'done': false, 'date': 'TBA'},
          {'name': 'Document Verification','done': false, 'date': 'TBA'},
        ];
      case 'UPSC':
        return [
          {'name': 'Application',          'done': true,  'date': ''},
          {'name': 'Prelims',             'done': false, 'date': 'TBA'},
          {'name': 'Mains',              'done': false, 'date': 'TBA'},
          {'name': 'Interview',          'done': false, 'date': 'TBA'},
          {'name': 'Document Verification','done': false, 'date': 'TBA'},
        ];
      default:
        return [
          {'name': 'Application',          'done': true,  'date': ''},
          {'name': 'Written Test',         'done': false, 'date': 'TBA'},
          {'name': 'Document Verification','done': false, 'date': 'TBA'},
        ];
    }
  }

  void _showAppliedSheet({
    required String jobId,
    required String title,
    required String organization,
    required String category,
  }) {
    final lang = context.read<LanguageProvider>().languageCode;
    final regNoController  = TextEditingController();
    final notesController  = TextEditingController();
    String selectedCategory = 'General';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSheet) => Container(
          height: MediaQuery.of(ctx2).size.height * 0.80,
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx2).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF10B981), size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(AppStrings.get('mark_as_applied_title', lang),
                        style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A1A2E))),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.close, color: Colors.grey),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: Colors.grey.shade500)),
                const SizedBox(height: 20),
                TextField(
                  controller: regNoController,
                  decoration: InputDecoration(
                    hintText: AppStrings.get('reg_no_hint', lang),
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    prefixIcon: Icon(Icons.confirmation_number_outlined,
                        color: const Color(0xFF1565C0), size: 20),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF1565C0), width: 2)),
                  ),
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
                const SizedBox(height: 12),
                StatefulBuilder(
                  builder: (ctx3, setLocal) =>
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        decoration: InputDecoration(
                          labelText: AppStrings.get('your_category_label', lang),
                          labelStyle: GoogleFonts.poppins(fontSize: 13),
                          prefixIcon: const Icon(Icons.category_outlined,
                              color: Color(0xFF1565C0), size: 20),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade200)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade200)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Color(0xFF1565C0), width: 2)),
                        ),
                        items: ['General', 'OBC', 'SC', 'ST', 'EWS']
                            .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c, style: GoogleFonts.poppins(fontSize: 14)),
                        ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setLocal(() => selectedCategory = v);
                        },
                      ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: AppStrings.get('notes_hint', lang),
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    prefixIcon: Icon(Icons.notes_outlined,
                        color: const Color(0xFF1565C0), size: 20),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF1565C0), width: 2)),
                  ),
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _markAsApplied(
                        jobId:        jobId,
                        title:        title,
                        organization: organization,
                        category:     category,
                        regNo:        regNoController.text.trim(),
                        notes:        notesController.text.trim(),
                        userCategory: selectedCategory,
                      );
                    },
                    icon: const Icon(Icons.check_rounded, color: Colors.white),
                    label: Text(AppStrings.get('confirm_applied_btn', lang),
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().languageCode;
    final Map<String, dynamic> job =
        (ModalRoute.of(context)?.settings.arguments
        as Map<String, dynamic>?) ?? {};

    final String jobId        = job['id'] as String? ?? '';
    final String title        = job['title'] as String? ?? 'Job Details';
    final String organization = job['organization'] as String?
        ?? job['department'] as String? ?? '';
    final String category     = job['category'] as String? ?? 'SSC';
    final String salary       = job['salary'] as String? ?? 'N/A';
    final String lastDate     = job['lastDate'] as String? ?? 'N/A';
    final String examDate     = job['examDate'] as String? ?? 'N/A';
    final String qualification= job['qualification'] as String? ?? 'N/A';

    final int vacancies = (() {
      final v = job['vacancies'] ?? job['posts'];
      if (v == null) return 0;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? 0;
    })();

    final int fee = (() {
      final v = job['fee'];
      if (v == null) return 0;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? 0;
    })();

    final int ageMin = (() {
      final v = job['ageMin'];
      if (v == null) return 18;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? 18;
    })();
    final int ageMax = (() {
      final v = job['ageMax'];
      if (v == null) return 35;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? 35;
    })();
    final String ageLimit = job['ageLimit'] as String?
        ?? '$ageMin - $ageMax years';

    final Color catColor = _categoryColor(category);
    final String url     = job['applyLink'] as String?
        ?? job['officialLink'] as String?
        ?? _getOfficialWebsite(category, title);

    final List<dynamic> selectionProcess = (() {
      final v = job['selectionProcess'];
      if (v == null) return <dynamic>[];
      if (v is List) return v;
      if (v is String && v.isNotEmpty) {
        return v.split('→').map((s) => s.trim()).toList();
      }
      return <dynamic>[];
    })();

    final Map<String, dynamic> syllabus = (() {
      final v = job['syllabus'];
      if (v == null) return <String, dynamic>{};
      if (v is Map<String, dynamic>) return v;
      if (v is String && v.isNotEmpty) {
        return <String, dynamic>{'Syllabus': v};
      }
      return <String, dynamic>{};
    })();

    final String notes        = job['notes'] as String? ?? '';
    final String examPattern  = job['examPattern'] as String? ?? '';
    final String applyLink    = job['applyLink'] as String? ?? url;
    final String applicationFee = job['applicationFee'] as String? ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 195,
              pinned: true,
              backgroundColor: catColor,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/jobs'),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                      _isSaved ? Icons.bookmark : Icons.bookmark_border,
                      color: Colors.white),
                  onPressed: () => _saveJob(jobId, title),
                ),
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.white),
                  onPressed: () {
                    Share.share(
                      '📢 $title\n'
                          '🏢 $organization\n'
                          '🔗 Apply here: $url\n\n'
                          'Found on ExamTrack — India\'s smartest govt job app!',
                      subject: '$title — Apply Now',
                    );
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [catColor, catColor.withOpacity(0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 80, 20, 60),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(category,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 6),
                        Text(title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(organization,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withOpacity(0.6),
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 12),
                tabs: [
                  Tab(text: AppStrings.get('tab_overview', lang)),
                  Tab(text: AppStrings.get('tab_selection', lang)),
                  Tab(text: AppStrings.get('tab_syllabus', lang)),
                  Tab(text: AppStrings.get('tab_papers', lang)),
                ],
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(job, title, vacancies, lastDate, examDate,
                salary, qualification, fee, ageMin, ageMax, catColor,
                ageLimit, applicationFee, examPattern, notes, lang),
            _buildSelectionTab(catColor, selectionProcess, lang),
            _buildSyllabusTab(catColor, syllabus, category, title, lang),
            _buildPapersTab(title, category, catColor, lang),
          ],
        ),
      ),
      bottomNavigationBar: _buildApplyButton(
          catColor, jobId, title, organization, category, url, lang),
    );
  }

  Widget _buildOverviewTab(
      Map<String, dynamic> job,
      String title,
      int vacancies,
      String lastDate,
      String examDate,
      String salary,
      String qualification,
      int fee,
      int ageMin,
      int ageMax,
      Color catColor,
      String ageLimit,
      String applicationFee,
      String examPattern,
      String notes,
      String lang,
      ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: _buildInfoCard(
                AppStrings.get('total_vacancies', lang),
                vacancies == 0 ? 'N/A' : '$vacancies',
                Icons.people_rounded, catColor)),
            const SizedBox(width: 12),
            Expanded(child: _buildInfoCard(AppStrings.get('last_date_label', lang),
                lastDate == 'TBA' ? AppStrings.get('not_announced', lang) : lastDate,
                Icons.calendar_today_rounded, Colors.orange)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _buildInfoCard(AppStrings.get('salary_label', lang),
                salary.startsWith('₹') ? salary : '₹$salary',
                Icons.currency_rupee_rounded, Colors.green)),
            const SizedBox(width: 12),
            Expanded(child: _buildInfoCard(
                AppStrings.get('qualification_label', lang), qualification,
                Icons.school_rounded, Colors.purple, allowExpand: true)),
          ]),
          const SizedBox(height: 20),
          _buildSection(AppStrings.get('age_limit_section', lang), Icons.cake_rounded,
            Column(children: [
              if (ageLimit.isNotEmpty && ageMin == 18 && ageMax == 35)
                _buildDetailRow(AppStrings.get('age_limit_section', lang), ageLimit)
              else ...[
                _buildDetailRow(AppStrings.get('minimum_age', lang), '$ageMin ${AppStrings.get('years_suffix', lang)}'),
                _buildDetailRow(AppStrings.get('maximum_age', lang), '$ageMax ${AppStrings.get('years_suffix', lang)}'),
              ],
              _buildDetailRow(AppStrings.get('obc_relaxation', lang), '+3 ${AppStrings.get('years_suffix', lang)}'),
              _buildDetailRow(AppStrings.get('scst_relaxation', lang), '+5 ${AppStrings.get('years_suffix', lang)}'),
            ]),
          ),
          const SizedBox(height: 16),
          _buildSection(AppStrings.get('application_fee_section', lang), Icons.payment_rounded,
            Column(children: [
              if (applicationFee.isNotEmpty)
                _buildDetailRow(AppStrings.get('fee_details', lang), applicationFee)
              else ...[
                _buildDetailRow(AppStrings.get('general_obc_label', lang),
                    fee == 0 ? AppStrings.get('no_fee', lang) : '₹$fee'),
                _buildDetailRow(AppStrings.get('scst_pwd_female', lang),
                    fee == 0 ? AppStrings.get('no_fee', lang)
                        : '₹${(fee * 0.6).toInt()} ${AppStrings.get('approx_suffix', lang)}'),
              ],
              _buildDetailRow(AppStrings.get('payment_mode', lang), AppStrings.get('online_only', lang)),
            ]),
          ),
          const SizedBox(height: 16),
          _buildSection(AppStrings.get('important_dates_section', lang), Icons.event_rounded,
            Column(children: [
              _buildDetailRow(AppStrings.get('last_date_to_apply', lang),
                  lastDate == 'TBA' ? AppStrings.get('not_announced_yet', lang) : lastDate),
              _buildDetailRow(AppStrings.get('exam_date_section', lang),
                  examDate == 'TBA' ? AppStrings.get('not_announced_yet', lang) : examDate),
            ]),
          ),
          if (examPattern.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSection(AppStrings.get('exam_pattern_section', lang), Icons.quiz_rounded,
              Column(children: [
                _buildDetailRow(AppStrings.get('pattern_label', lang), examPattern),
              ]),
            ),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSection(AppStrings.get('important_notes_section', lang), Icons.info_rounded,
              Column(children: [
                _buildDetailRow(AppStrings.get('note_label', lang), notes),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectionTab(Color catColor, List<dynamic> selectionProcess, String lang) {
    if (selectionProcess.isEmpty) {
      return _buildNoDataWidget(
          AppStrings.get('selection_empty_title', lang),
          AppStrings.get('selection_empty_sub', lang),
          Icons.fact_check_outlined, catColor);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: catColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: catColor.withOpacity(0.3)),
          ),
          child: Row(children: [
            Icon(Icons.info_outline, color: catColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${AppStrings.get('selection_stages_info', lang)} '
                    '${selectionProcess.length} '
                    '${AppStrings.get('stages_clear_info', lang)}',
                style: TextStyle(color: catColor, fontSize: 13),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        ...selectionProcess.asMap().entries.map((entry) {
          final index = entry.key;
          final dynamic raw = entry.value;
          final bool hasConnector = index < selectionProcess.length - 1;

          if (raw is String) {
            return _buildSimpleStageCard(
                index + 1, raw, hasConnector, catColor);
          } else if (raw is Map) {
            return _buildDynamicStageCard(
                Map<String, dynamic>.from(raw), hasConnector, catColor);
          }
          return const SizedBox();
        }),
      ]),
    );
  }

  Widget _buildSimpleStageCard(int stageNum, String stageName,
      bool hasConnector, Color catColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: catColor, shape: BoxShape.circle,
              boxShadow: [BoxShadow(
                  color: catColor.withOpacity(0.3),
                  blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Center(child: Text('$stageNum',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16, fontWeight: FontWeight.bold))),
          ),
          if (hasConnector)
            Container(width: 2, height: 40, color: Colors.grey.shade300),
        ]),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Text(stageName,
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w500,
                    color: const Color(0xFF1A1A2E))),
          ),
        ),
      ],
    );
  }

  Widget _buildDynamicStageCard(Map<String, dynamic> stage,
      bool hasConnector, Color catColor) {
    final int stageNum   = (stage['stage'] ?? 1) as int;
    final String name    = stage['name'] as String? ?? '';
    final String type    = stage['type'] as String? ?? '';
    final List<dynamic> details = stage['details'] as List<dynamic>? ?? [];

    bool isExpanded = false;

    return StatefulBuilder(
      builder: (context, setStateLocal) {
        return Column(children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: catColor, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                        color: catColor.withOpacity(0.3),
                        blurRadius: 8, offset: const Offset(0, 4))],
                  ),
                  child: Center(child: Text('$stageNum',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 18,
                          fontWeight: FontWeight.bold))),
                ),
                if (hasConnector)
                  Container(width: 2,
                      height: isExpanded ? 20 : 40,
                      color: Colors.grey.shade300),
              ]),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () =>
                      setStateLocal(() => isExpanded = !isExpanded),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8, offset: const Offset(0, 4))],
                    ),
                    child: Column(children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: catColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_stageIcon(type),
                                color: catColor, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A2E))),
                              Text(type, style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade500)),
                            ],
                          )),
                          Icon(isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                              color: Colors.grey),
                        ]),
                      ),
                      if (isExpanded) ...[
                        Divider(height: 1, color: Colors.grey.shade100),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: details.map((d) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.check_circle,
                                      size: 16, color: catColor),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(d.toString(),
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF1A1A2E),
                                          height: 1.4))),
                                ],
                              ),
                            )).toList(),
                          ),
                        ),
                      ],
                    ]),
                  ),
                ),
              ),
            ],
          ),
        ]);
      },
    );
  }

  IconData _stageIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('computer') || t.contains('cbt') ||
        t.contains('written') || t.contains('online')) return Icons.computer_rounded;
    if (t.contains('physical') || t.contains('fitness')) return Icons.fitness_center_rounded;
    if (t.contains('medical')) return Icons.medical_services_rounded;
    if (t.contains('interview')) return Icons.record_voice_over_rounded;
    if (t.contains('skill') || t.contains('typing')) return Icons.keyboard_rounded;
    if (t.contains('merit')) return Icons.leaderboard_rounded;
    return Icons.verified_rounded;
  }

  String _getOfficialSiteUrl(String category, String title) {
    final t = title.toLowerCase();
    if (t.contains('ntpc') || t.contains('alp') || t.contains('group d') ||
        t.contains('rrb') || t.contains('rpf') || t.contains('technician') ||
        category == 'Railway') return 'https://www.rrbcdg.gov.in';
    if (t.contains('ssc') || category == 'SSC') return 'https://ssc.gov.in';
    if (t.contains('sbi')) return 'https://bank.sbi/web/careers';
    if (t.contains('ibps') || category == 'Banking') return 'https://www.ibps.in';
    if (t.contains('nda') || t.contains('cds') || t.contains('upsc') ||
        t.contains('ias') || category == 'UPSC') return 'https://upsc.gov.in';
    if (t.contains('agniveer') || t.contains('army') || t.contains('soldier') ||
        category == 'Army') return 'https://joinindianarmy.nic.in';
    if (t.contains('navy') || t.contains('ssr') || t.contains('mr'))
      return 'https://www.joinindiannavy.gov.in';
    if (t.contains('afcat') || t.contains('air force'))
      return 'https://careerindianairforce.cdac.in';
    if (t.contains('agniveervayu')) return 'https://agnipathvayu.cdac.in';
    if (t.contains('bro') || t.contains('border roads')) return 'https://bro.gov.in';
    if (t.contains('ctet')) return 'https://ctet.nic.in';
    if (t.contains('htet') || t.contains('haryana') && t.contains('teacher'))
      return 'https://www.haryanatet.in';
    if (t.contains('pstet') || t.contains('punjab') && t.contains('teacher'))
      return 'https://pstet.pseb.ac.in';
    if (category == 'Teaching') return 'https://ctet.nic.in';
    if (t.contains('haryana') || t.contains('hssc') || category == 'Police' && t.contains('haryana'))
      return 'https://haryanapoliceonline.gov.in';
    if (t.contains('psssb') || t.contains('punjab subordinate'))
      return 'https://sssb.punjab.gov.in';
    if (category == 'Police') return 'https://punjabpolice.gov.in';
    if (t.contains('aiims')) return 'https://www.aiimsexams.ac.in';
    if (t.contains('nhm')) return 'https://nhm.punjab.gov.in';
    if (category == 'Health') return 'https://nhm.punjab.gov.in';
    return 'https://ncs.gov.in';
  }

  String _getOfficialSiteName(String category, String title) {
    final t = title.toLowerCase();
    if (t.contains('ntpc') || t.contains('alp') || t.contains('group d') ||
        t.contains('rrb') || category == 'Railway') return 'rrbcdg.gov.in';
    if (t.contains('ssc') || category == 'SSC') return 'ssc.gov.in';
    if (t.contains('sbi')) return 'bank.sbi';
    if (t.contains('ibps') || category == 'Banking') return 'ibps.in';
    if (t.contains('nda') || t.contains('cds') || t.contains('upsc') ||
        category == 'UPSC') return 'upsc.gov.in';
    if (t.contains('army') || t.contains('agniveer') || category == 'Army')
      return 'joinindianarmy.nic.in';
    if (t.contains('navy')) return 'joinindiannavy.gov.in';
    if (t.contains('afcat') || t.contains('air force'))
      return 'careerindianairforce.cdac.in';
    if (t.contains('ctet')) return 'ctet.nic.in';
    if (t.contains('htet')) return 'haryanatet.in';
    if (category == 'Police' && t.contains('haryana')) return 'haryanapoliceonline.gov.in';
    if (t.contains('psssb')) return 'sssb.punjab.gov.in';
    if (category == 'Police') return 'punjabpolice.gov.in';
    if (category == 'Health') return 'nhm.punjab.gov.in';
    return 'ncs.gov.in';
  }

  Widget _buildSyllabusTab(Color catColor,
      Map<String, dynamic> syllabus, String category, String title, String lang) {

    final officialUrl  = _getOfficialSiteUrl(category, title);
    final officialName = _getOfficialSiteName(category, title);

    final officialButton = GestureDetector(
      onTap: () => _openURL(context, officialUrl),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [catColor, catColor.withOpacity(0.85)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
              color: catColor.withOpacity(0.3),
              blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.language_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppStrings.get('find_syllabus_official', lang),
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              Text(officialName,
                  style: GoogleFonts.poppins(
                      color: Colors.white70, fontSize: 11)),
            ],
          )),
          const Icon(Icons.open_in_new_rounded,
              color: Colors.white, size: 18),
        ]),
      ),
    );

    if (syllabus.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          officialButton,
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.05), blurRadius: 8)],
            ),
            child: Column(children: [
              Icon(Icons.menu_book_outlined,
                  size: 52, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(AppStrings.get('syllabus_not_available', lang),
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w600,
                      color: const Color(0xFF374151))),
              const SizedBox(height: 6),
              Text(AppStrings.get('syllabus_tap_hint', lang),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: const Color(0xFF9CA3AF))),
            ]),
          ),
        ]),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        officialButton,
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withOpacity(0.4)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline, color: Colors.amber, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppStrings.get('syllabus_disclaimer', lang),
                style: GoogleFonts.poppins(
                    fontSize: 11, color: Colors.amber.shade800),
              ),
            ),
          ]),
        ),

        // Syllabus topics from Firestore — subject names and topics
        // are NOT translated (real exam content, not app UI chrome).
        ...syllabus.entries.map((entry) {
          final subjectName = entry.key;
          final dynamic rawValue = entry.value;
          List<String> topics = [];
          if (rawValue is String) {
            topics = rawValue
                .split(',')
                .map((t) => t.trim())
                .where((t) => t.isNotEmpty)
                .toList();
          } else if (rawValue is List) {
            topics = rawValue.map((t) => t.toString()).toList();
          }
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: ExpansionTile(
              initiallyExpanded: true,
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: catColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.book_rounded, color: catColor, size: 22),
              ),
              title: Text(subjectName,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold)),
              subtitle: Text(
                  topics.length == 1
                      ? AppStrings.get('tap_to_expand', lang)
                      : '${topics.length} ${AppStrings.get('topics_suffix', lang)}',
                  style: TextStyle(fontSize: 12, color: catColor)),
              children: topics.map((topic) => ListTile(
                dense: true,
                leading: Icon(Icons.arrow_right_rounded, color: catColor),
                title: Text(topic.toString(),
                    style: const TextStyle(fontSize: 13)),
              )).toList(),
            ),
          );
        }),
      ]),
    );
  }

  Widget _buildNoDataWidget(String title, String subtitle,
      IconData icon, Color color) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w600,
                    color: const Color(0xFF374151))),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: const Color(0xFF9CA3AF))),
          ],
        ),
      ),
    );
  }

  Widget _buildPapersTab(String title, String category, Color catColor, String lang) {
    // NOTE: paperSources content (names, descriptions of external sites)
    // intentionally NOT translated — these are real-world proper nouns
    // and official site descriptions, same treatment as job titles.
    final Map<String, List<Map<String, String>>> paperSources = {
      'SSC': [
        {
          'name': 'SSC Previous Year Papers',
          'source': 'ssc.gov.in',
          'url': 'https://ssc.gov.in/candidate-corner/previous-year-question-papers',
          'desc': 'Official SSC previous year question papers (login required)',
        },
        {
          'name': 'SSC Answer Keys',
          'source': 'ssc.gov.in',
          'url': 'https://ssc.gov.in/candidate-corner/answer-keys',
          'desc': 'Official answer keys for all SSC exams',
        },
        {
          'name': 'SSC Notifications & Updates',
          'source': 'ssc.gov.in',
          'url': 'https://ssc.gov.in/candidate-corner/notification',
          'desc': 'Latest notifications, syllabi and exam schedules',
        },
      ],
      'Railway': [
        {
          'name': 'RRB Official Portal',
          'source': 'rrbapply.gov.in',
          'url': 'https://rrbapply.gov.in',
          'desc': 'Official RRB application and exam portal',
        },
        {
          'name': 'RRB CDG Official Site',
          'source': 'rrbcdg.gov.in',
          'url': 'https://www.rrbcdg.gov.in',
          'desc': 'RRB Chandigarh — notifications and results',
        },
        {
          'name': 'Indian Railways Official',
          'source': 'indianrailways.gov.in',
          'url': 'https://www.indianrailways.gov.in',
          'desc': 'Ministry of Railways official website',
        },
      ],
      'Banking': [
        {
          'name': 'IBPS Official Portal',
          'source': 'ibps.in',
          'url': 'https://www.ibps.in',
          'desc': 'Official IBPS portal — notifications, results, admit cards',
        },
        {
          'name': 'SBI Official Careers',
          'source': 'sbi.co.in',
          'url': 'https://www.sbi.co.in/web/careers',
          'desc': 'SBI recruitment portal — PO, Clerk, SO',
        },
        {
          'name': 'RBI Opportunities',
          'source': 'rbi.org.in',
          'url': 'https://www.rbi.org.in/scripts/Opportunities.aspx',
          'desc': 'Reserve Bank of India recruitment',
        },
      ],
      'Police': [
        {
          'name': 'Punjab Police Official',
          'source': 'punjabpolice.gov.in',
          'url': 'https://punjabpolice.gov.in',
          'desc': 'Punjab Police official recruitment portal',
        },
        {
          'name': 'PSSSB Official Portal',
          'source': 'sssb.punjab.gov.in',
          'url': 'https://sssb.punjab.gov.in',
          'desc': 'Punjab Subordinate Services Selection Board',
        },
        {
          'name': 'HSSC Official Portal',
          'source': 'hssc.gov.in',
          'url': 'https://hssc.gov.in',
          'desc': 'Haryana Staff Selection Commission — recruitment portal',
        },
      ],
      'Army': [
        {
          'name': 'Join Indian Army',
          'source': 'joinindianarmy.nic.in',
          'url': 'https://joinindianarmy.nic.in',
          'desc': 'Official Indian Army recruitment portal',
        },
        {
          'name': 'Join Indian Navy',
          'source': 'joinindiannavy.gov.in',
          'url': 'https://joinindiannavy.gov.in',
          'desc': 'Official Indian Navy recruitment portal',
        },
        {
          'name': 'Indian Air Force Recruitment',
          'source': 'careerindianairforce.cdac.in',
          'url': 'https://careerindianairforce.cdac.in',
          'desc': 'Indian Air Force official recruitment portal',
        },
      ],
      'UPSC': [
        {
          'name': 'UPSC Previous Year Papers',
          'source': 'upsc.gov.in',
          'url': 'https://www.upsc.gov.in/examinations/previous-question-papers',
          'desc': 'Official UPSC previous year question papers — free download',
        },
        {
          'name': 'UPSC Active Examinations',
          'source': 'upsc.gov.in',
          'url': 'https://upsc.gov.in/examinations/active-examinations',
          'desc': 'Currently active UPSC examinations and notifications',
        },
        {
          'name': 'UPSC Online Application',
          'source': 'upsconline.nic.in',
          'url': 'https://upsconline.nic.in',
          'desc': 'UPSC online application portal',
        },
      ],
      'Teaching': [
        {
          'name': 'CTET Official Portal',
          'source': 'ctet.nic.in',
          'url': 'https://ctet.nic.in',
          'desc': 'Central Teacher Eligibility Test — official portal',
        },
        {
          'name': 'Punjab Education Recruitment Board',
          'source': 'educationrecruitmentboard.com',
          'url': 'https://educationrecruitmentboard.com',
          'desc': 'Punjab Teacher Recruitment — official portal',
        },
        {
          'name': 'HTET Official Portal',
          'source': 'haryanatet.in',
          'url': 'https://www.haryanatet.in',
          'desc': 'Haryana Teacher Eligibility Test — official portal',
        },
      ],
      'Health': [
        {
          'name': 'NHM Punjab Official',
          'source': 'nhm.punjab.gov.in',
          'url': 'https://nhm.punjab.gov.in',
          'desc': 'National Health Mission Punjab — recruitment portal',
        },
        {
          'name': 'BFUHS Official Portal',
          'source': 'bfuhs.ac.in',
          'url': 'https://www.bfuhs.ac.in',
          'desc': 'Baba Farid University of Health Sciences — recruitment',
        },
        {
          'name': 'AIIMS Recruitment',
          'source': 'aiimsexams.ac.in',
          'url': 'https://www.aiimsexams.ac.in',
          'desc': 'All India Institute of Medical Sciences — recruitment',
        },
      ],
    };

    final sources = paperSources[category] ?? paperSources['SSC']!;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: catColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: catColor.withOpacity(0.25)),
          ),
          child: Row(children: [
            Icon(Icons.info_outline, color: catColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppStrings.get('papers_tap_hint', lang),
                style: GoogleFonts.poppins(
                    fontSize: 12, color: catColor, height: 1.4),
              ),
            ),
          ]),
        ),
        ...sources.map((paper) => GestureDetector(
          onTap: () => _openURL(context, paper['url']!),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Row(children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: catColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.picture_as_pdf_rounded,
                    color: catColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(paper['name']!,
                      style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A1A2E))),
                  const SizedBox(height: 2),
                  Text(paper['desc']!,
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: Colors.grey.shade500)),
                  const SizedBox(height: 4),
                  Text(paper['source']!,
                      style: GoogleFonts.poppins(
                          fontSize: 10, color: catColor,
                          fontWeight: FontWeight.w600)),
                ],
              )),
              Icon(Icons.open_in_new_rounded, color: catColor, size: 18),
            ]),
          ),
        )),
      ],
    );
  }

  Widget _buildSection(String title, IconData icon, Widget content) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E))),
            ]),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          Padding(padding: const EdgeInsets.all(16), child: content),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E))),
          ),
        ],
      ),
    );
  }

  // Shows the complete, untruncated value in a bottom sheet — used when
  // an info card's value is too long to display in the compact card
  // (e.g. multi-branch qualification strings with several distinct
  // requirements separated by "|").
  void _showFullValueSheet(String label, String value, Color color) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.6,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: color)),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                // Splitting on "|" (the separator used for multi-branch
                // / multi-category values) renders each part as its own
                // line instead of one dense run-on paragraph.
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: value.split('|').map((part) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(part.trim(),
                        style: GoogleFonts.poppins(
                            fontSize: 14, color: const Color(0xFF1A1A2E),
                            height: 1.5)),
                  )).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value,
      IconData icon, Color color, {bool allowExpand = false}) {
    final bool isLong = value.length > 28;
    return GestureDetector(
      onTap: (allowExpand && isLong)
          ? () => _showFullValueSheet(label, value, color)
          : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(
                  fontSize: 11, color: Colors.grey.shade500)),
              // Capped at 2 lines with ellipsis — long compound values
              // (e.g. multi-branch qualification strings) no longer
              // stretch this card taller than its row partner.
              Text(value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E))),
              if (allowExpand && isLong)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('Tap to see full details',
                      style: TextStyle(
                          fontSize: 10, color: color,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          )),
        ]),
      ),
    );
  }

  Widget _buildApplyButton(Color catColor, String jobId, String title,
      String organization, String category, String url, String lang) {
    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 12,
        bottom: 16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: _isApplied
                ? null
                : () => _showAppliedSheet(
              jobId:        jobId,
              title:        title,
              organization: organization,
              category:     category,
            ),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: _isApplied ? const Color(0xFF10B981) : Colors.white,
                border: Border.all(
                    color: _isApplied
                        ? const Color(0xFF10B981)
                        : const Color(0xFF10B981)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  _isApplied ? AppStrings.get('applied_check', lang) : AppStrings.get('mark_applied', lang),
                  style: TextStyle(
                      color: _isApplied ? Colors.white : const Color(0xFF10B981),
                      fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: () => _openURL(context, url),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [catColor, catColor.withOpacity(0.8)]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(
                    color: catColor.withOpacity(0.3),
                    blurRadius: 12, offset: const Offset(0, 6))],
              ),
              child: Center(
                child: Text(AppStrings.get('apply_now_btn', lang),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
