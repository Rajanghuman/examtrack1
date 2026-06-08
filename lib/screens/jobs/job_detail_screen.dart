import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../constants/app_colors.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Custom Toast (Bug 2 Fix) ───────────────────────────
  void _showToast(BuildContext context, String message,
      {bool success = true}) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      builder: (ctx) {
        Future.delayed(
            const Duration(seconds: 2), () {
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
    } else if (t.contains('psssb') ||
        t.contains('punjab subordinate')) {
      return 'https://sssb.punjab.gov.in';
    } else if (category == 'Police') {
      return 'https://punjabpolice.gov.in';
    } else if (t.contains('army') || t.contains('agniveer') ||
        t.contains('soldier')) {
      return 'https://joinindianarmy.nic.in';
    } else if (t.contains('bro') ||
        t.contains('border roads')) {
      return 'https://bro.gov.in';
    } else if (category == 'Army') {
      return 'https://joinindianarmy.nic.in';
    } else if (t.contains('upsc') || t.contains('ias') ||
        t.contains('ips') || t.contains('cds') ||
        category == 'UPSC') {
      return 'https://upsconline.nic.in';
    } else if (t.contains('ctet')) {
      return 'https://ctet.nic.in';
    } else if (t.contains('teaching') ||
        t.contains('teacher') || t.contains('punjab') ||
        category == 'Teaching') {
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
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri,
          mode: LaunchMode.externalApplication);
    } else {
      _showToast(context, 'Could not open link!',
          success: false);
    }
  }

  Future<void> _saveJob(String jobId, String title) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showToast(context, 'Please login to save jobs!',
            success: false);
        return;
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'savedJobs': FieldValue.arrayUnion([jobId]),
      }, SetOptions(merge: true));
      setState(() => _isSaved = true);
      _showToast(context, '$title saved! ✅');
    } catch (e) {
      _showToast(context, 'Error saving job. Try again!',
          success: false);
    }
  }

  // ── Mark as Applied ────────────────────────────────────
  Future<void> _markAsApplied({
    required String jobId,
    required String title,
    required String organization,
    required String category,
    required String regNo,
    required String notes,
    required String userCategory,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final appliedDate =
          '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';

      // 1. Add to appliedJobs array on user doc (for profile stats)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'appliedJobs': FieldValue.arrayUnion([title]),
      }, SetOptions(merge: true));

      // 2. Add to trackedJobs array on user doc (for tracker stats)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'trackedJobs': FieldValue.arrayUnion([title]),
      }, SetOptions(merge: true));

      // 3. Add to trackedJobs subcollection (for Job Tracker screen)
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

      setState(() => _isApplied = true);
      _showToast(context, 'Marked as Applied! ✅');
    } catch (e) {
      _showToast(context, 'Error. Try again!', success: false);
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
          {'name': 'Application',           'done': true,  'date': ''},
          {'name': 'Written Test',           'done': false, 'date': 'TBA'},
          {'name': 'Physical Test',          'done': false, 'date': 'TBA'},
          {'name': 'Medical Test',           'done': false, 'date': 'TBA'},
          {'name': 'Document Verification',  'done': false, 'date': 'TBA'},
        ];
      case 'Banking':
        return [
          {'name': 'Application',           'done': true,  'date': ''},
          {'name': 'Prelims',               'done': false, 'date': 'TBA'},
          {'name': 'Mains',                 'done': false, 'date': 'TBA'},
          {'name': 'Interview',             'done': false, 'date': 'TBA'},
          {'name': 'Document Verification', 'done': false, 'date': 'TBA'},
        ];
      case 'Army':
        return [
          {'name': 'Application',           'done': true,  'date': ''},
          {'name': 'Physical Test',         'done': false, 'date': 'TBA'},
          {'name': 'Written Test',          'done': false, 'date': 'TBA'},
          {'name': 'Medical Test',          'done': false, 'date': 'TBA'},
          {'name': 'Document Verification', 'done': false, 'date': 'TBA'},
        ];
      case 'UPSC':
        return [
          {'name': 'Application',           'done': true,  'date': ''},
          {'name': 'Prelims',               'done': false, 'date': 'TBA'},
          {'name': 'Mains',                 'done': false, 'date': 'TBA'},
          {'name': 'Interview',             'done': false, 'date': 'TBA'},
          {'name': 'Document Verification', 'done': false, 'date': 'TBA'},
        ];
      default:
        return [
          {'name': 'Application',           'done': true,  'date': ''},
          {'name': 'Written Test',          'done': false, 'date': 'TBA'},
          {'name': 'Document Verification', 'done': false, 'date': 'TBA'},
        ];
    }
  }

  // ── Show "Mark as Applied" bottom sheet ────────────────
  void _showAppliedSheet({
    required String jobId,
    required String title,
    required String organization,
    required String category,
  }) {
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
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF10B981), size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Mark as Applied',
                          style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1A2E))),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: const Icon(Icons.close,
                          color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey.shade500)),
                const SizedBox(height: 20),

                // Registration number field
                TextField(
                  controller: regNoController,
                  decoration: InputDecoration(
                    hintText: 'Registration Number (optional)',
                    hintStyle: TextStyle(
                        color: Colors.grey.shade400, fontSize: 14),
                    prefixIcon: Icon(
                        Icons.confirmation_number_outlined,
                        color: const Color(0xFF1565C0), size: 20),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Colors.grey.shade200)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Colors.grey.shade200)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF1565C0), width: 2)),
                  ),
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
                const SizedBox(height: 12),

                // Category dropdown
                StatefulBuilder(
                  builder: (ctx3, setLocal) =>
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        decoration: InputDecoration(
                          labelText: 'Your Category',
                          labelStyle: GoogleFonts.poppins(
                              fontSize: 13),
                          prefixIcon: const Icon(
                              Icons.category_outlined,
                              color: Color(0xFF1565C0),
                              size: 20),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                              borderRadius:
                              BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: Colors.grey.shade200)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius:
                              BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: Colors.grey.shade200)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius:
                              BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Color(0xFF1565C0),
                                  width: 2)),
                        ),
                        items: ['General', 'OBC', 'SC', 'ST', 'EWS']
                            .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c,
                              style: GoogleFonts.poppins(
                                  fontSize: 14)),
                        ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setLocal(() =>
                            selectedCategory = v);
                          }
                        },
                      ),
                ),
                const SizedBox(height: 12),

                // Notes field
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Notes (optional)',
                    hintStyle: TextStyle(
                        color: Colors.grey.shade400, fontSize: 14),
                    prefixIcon: Icon(Icons.notes_outlined,
                        color: const Color(0xFF1565C0), size: 20),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Colors.grey.shade200)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Colors.grey.shade200)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF1565C0), width: 2)),
                  ),
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
                const SizedBox(height: 20),

                // Confirm button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _markAsApplied(
                        jobId:         jobId,
                        title:         title,
                        organization:  organization,
                        category:      category,
                        regNo:         regNoController.text.trim(),
                        notes:         notesController.text.trim(),
                        userCategory:  selectedCategory,
                      );
                    },
                    icon: const Icon(Icons.check_rounded,
                        color: Colors.white),
                    label: Text('Confirm — I Applied!',
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

    // Support both 'vacancies' (int) and 'posts' (int) fields
    final int vacancies = (() {
      final v = job['vacancies'] ?? job['posts'];
      if (v == null) return 0;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? 0;
    })();

    // Support both fee (int) and applicationFee (string)
    final int fee = (() {
      final v = job['fee'];
      if (v == null) return 0;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? 0;
    })();

    // Support both ageMin/ageMax (int) and ageLimit (string)
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
    // ageLimit string for new jobs
    final String ageLimit = job['ageLimit'] as String?
        ?? '$ageMin - $ageMax years';

    final Color catColor      = _categoryColor(category);
    final String url          = job['applyLink'] as String?
        ?? job['officialLink'] as String?
        ?? _getOfficialWebsite(category, title);

    // ── Read dynamic data from Firestore job document ──
    // selectionProcess can be List or String — handle both
    final List<dynamic> selectionProcess = (() {
      final v = job['selectionProcess'];
      if (v == null) return <dynamic>[];
      if (v is List) return v;
      if (v is String && v.isNotEmpty) {
        return v.split('→').map((s) => s.trim()).toList();
      }
      return <dynamic>[];
    })();

    // syllabus can be Map or String — handle both
    final Map<String, dynamic> syllabus = (() {
      final v = job['syllabus'];
      if (v == null) return <String, dynamic>{};
      if (v is Map<String, dynamic>) return v;
      if (v is String && v.isNotEmpty) {
        return <String, dynamic>{'Syllabus': v};
      }
      return <String, dynamic>{};
    })();

    // Extra info for new job format
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
                icon: const Icon(Icons.arrow_back,
                    color: Colors.white),
                onPressed: () =>
                    Navigator.pushReplacementNamed(
                        context, '/jobs'),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                      _isSaved
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      color: Colors.white),
                  onPressed: () => _saveJob(jobId, title),
                ),
                IconButton(
                  icon: const Icon(Icons.share,
                      color: Colors.white),
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
                      colors: [
                        catColor,
                        catColor.withOpacity(0.8)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        20, 80, 20, 60),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white
                                .withOpacity(0.2),
                            borderRadius:
                            BorderRadius.circular(6),
                          ),
                          child: Text(category,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight:
                                  FontWeight.w600)),
                        ),
                        const SizedBox(height: 6),
                        Text(title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight:
                                FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(organization,
                            style: TextStyle(
                                color: Colors.white
                                    .withOpacity(0.8),
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
                unselectedLabelColor:
                Colors.white.withOpacity(0.6),
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
                unselectedLabelStyle:
                const TextStyle(fontSize: 12),
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Selection'),
                  Tab(text: 'Syllabus'),
                  Tab(text: 'Papers'),
                ],
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(job, title, vacancies,
                lastDate, examDate, salary, qualification,
                fee, ageMin, ageMax, catColor, ageLimit, applicationFee, examPattern, notes),
            _buildSelectionTab(catColor, selectionProcess),
            _buildSyllabusTab(catColor, syllabus),
            _buildPapersTab(title, category, catColor),
          ],
        ),
      ),
      bottomNavigationBar:
      _buildApplyButton(catColor, jobId, title,
          organization, category, url),
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
      ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _buildInfoCard(
                  'Total Vacancies',
                  vacancies == 0 ? 'N/A' : '$vacancies',
                  Icons.people_rounded, catColor)),
              const SizedBox(width: 12),
              Expanded(child: _buildInfoCard('Last Date',
                  lastDate == 'TBA'
                      ? 'Not Announced'
                      : lastDate,
                  Icons.calendar_today_rounded,
                  Colors.orange)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildInfoCard('Salary',
                  salary.startsWith('₹') ? salary : '₹$salary',
                  Icons.currency_rupee_rounded,
                  Colors.green)),
              const SizedBox(width: 12),
              Expanded(child: _buildInfoCard(
                  'Qualification', qualification,
                  Icons.school_rounded, Colors.purple)),
            ],
          ),
          const SizedBox(height: 20),
          _buildSection('Age Limit', Icons.cake_rounded,
            Column(children: [
              if (ageLimit.isNotEmpty && ageMin == 18 && ageMax == 35)
                _buildDetailRow('Age Limit', ageLimit)
              else ...[
                _buildDetailRow('Minimum Age', '$ageMin Years'),
                _buildDetailRow('Maximum Age', '$ageMax Years'),
              ],
              _buildDetailRow('OBC Relaxation', '+3 Years'),
              _buildDetailRow('SC/ST Relaxation', '+5 Years'),
            ]),
          ),
          const SizedBox(height: 16),
          _buildSection('Application Fee',
            Icons.payment_rounded,
            Column(children: [
              if (applicationFee.isNotEmpty)
                _buildDetailRow('Fee Details', applicationFee)
              else ...[
                _buildDetailRow('General/OBC',
                    fee == 0 ? 'No Fee' : '₹$fee'),
                _buildDetailRow('SC/ST/PWD/Female',
                    fee == 0 ? 'No Fee'
                        : '₹${(fee * 0.6).toInt()} approx'),
              ],
              _buildDetailRow('Payment Mode', 'Online Only'),
            ]),
          ),
          const SizedBox(height: 16),
          _buildSection('Important Dates',
            Icons.event_rounded,
            Column(children: [
              _buildDetailRow('Last Date to Apply',
                  lastDate == 'TBA'
                      ? 'Not Announced Yet'
                      : lastDate),
              _buildDetailRow('Exam Date',
                  examDate == 'TBA'
                      ? 'Not Announced Yet'
                      : examDate),
            ]),
          ),
          if (examPattern.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSection('Exam Pattern',
              Icons.quiz_rounded,
              Column(children: [
                _buildDetailRow('Pattern', examPattern),
              ]),
            ),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSection('Important Notes',
              Icons.info_rounded,
              Column(children: [
                _buildDetailRow('Note', notes),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  // ── Dynamic Selection Tab from Firestore ──────────────
  Widget _buildSelectionTab(
      Color catColor, List<dynamic> selectionProcess) {

    if (selectionProcess.isEmpty) {
      return _buildNoDataWidget(
          'Selection process will be updated soon!',
          'Check official notification for details',
          Icons.fact_check_outlined,
          catColor);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: catColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: catColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: catColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Complete selection process has '
                        '${selectionProcess.length} stages. '
                        'Clear each stage to proceed.',
                    style: TextStyle(
                        color: catColor, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...selectionProcess.asMap().entries.map((entry) {
            final index  = entry.key;
            final dynamic raw = entry.value;
            final bool hasConnector =
                index < selectionProcess.length - 1;

            // Handle both String and Map formats
            if (raw is String) {
              return _buildSimpleStageCard(
                  index + 1, raw, hasConnector, catColor);
            } else if (raw is Map) {
              return _buildDynamicStageCard(
                  Map<String, dynamic>.from(raw),
                  hasConnector, catColor);
            }
            return const SizedBox();
          }),
        ],
      ),
    );
  }

  // Simple stage card for String-format selectionProcess
  Widget _buildSimpleStageCard(
      int stageNum,
      String stageName,
      bool hasConnector,
      Color catColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: catColor,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                    color: catColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4))],
              ),
              child: Center(
                child: Text('$stageNum',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            if (hasConnector)
              Container(
                  width: 2, height: 40,
                  color: Colors.grey.shade300),
          ],
        ),
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
                  blurRadius: 8,
                  offset: const Offset(0, 4))],
            ),
            child: Text(stageName,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1A1A2E))),
          ),
        ),
      ],
    );
  }

  Widget _buildDynamicStageCard(
      Map<String, dynamic> stage,
      bool hasConnector,
      Color catColor) {
    final int stageNum   = (stage['stage'] ?? 1) as int;
    final String name    = stage['name'] as String? ?? '';
    final String type    = stage['type'] as String? ?? '';
    final List<dynamic> details =
        stage['details'] as List<dynamic>? ?? [];

    bool isExpanded = false;

    return StatefulBuilder(
      builder: (context, setStateLocal) {
        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: catColor,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(
                            color: catColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4))],
                      ),
                      child: Center(
                        child: Text('$stageNum',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                    if (hasConnector)
                      Container(
                          width: 2,
                          height: isExpanded ? 20 : 40,
                          color: Colors.grey.shade300),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setStateLocal(
                            () => isExpanded = !isExpanded),
                    child: Container(
                      margin: const EdgeInsets.only(
                          bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                        BorderRadius.circular(16),
                        boxShadow: [BoxShadow(
                            color: Colors.black
                                .withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding:
                            const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(
                                    color: catColor
                                        .withOpacity(0.1),
                                    borderRadius:
                                    BorderRadius
                                        .circular(10),
                                  ),
                                  child: Icon(
                                      _stageIcon(type),
                                      color: catColor,
                                      size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                    children: [
                                      Text(name,
                                          style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight:
                                              FontWeight.bold,
                                              color: Color(
                                                  0xFF1A1A2E))),
                                      Text(type,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors
                                                  .grey
                                                  .shade500)),
                                    ],
                                  ),
                                ),
                                Icon(
                                    isExpanded
                                        ? Icons
                                        .keyboard_arrow_up
                                        : Icons
                                        .keyboard_arrow_down,
                                    color: Colors.grey),
                              ],
                            ),
                          ),
                          if (isExpanded) ...[
                            Divider(
                                height: 1,
                                color: Colors.grey.shade100),
                            Padding(
                              padding:
                              const EdgeInsets.all(16),
                              child: Column(
                                children: details
                                    .map((d) => Padding(
                                  padding: const EdgeInsets
                                      .symmetric(
                                      vertical: 4),
                                  child: Row(
                                    crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                    children: [
                                      Icon(
                                          Icons
                                              .check_circle,
                                          size: 16,
                                          color:
                                          catColor),
                                      const SizedBox(
                                          width: 8),
                                      Expanded(
                                          child: Text(
                                              d.toString(),
                                              style: const TextStyle(
                                                  fontSize:
                                                  13,
                                                  color: Color(
                                                      0xFF1A1A2E),
                                                  height:
                                                  1.4))),
                                    ],
                                  ),
                                ))
                                    .toList(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  IconData _stageIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('computer') || t.contains('cbt') ||
        t.contains('written') || t.contains('online')) {
      return Icons.computer_rounded;
    } else if (t.contains('physical') ||
        t.contains('fitness')) {
      return Icons.fitness_center_rounded;
    } else if (t.contains('medical')) {
      return Icons.medical_services_rounded;
    } else if (t.contains('interview')) {
      return Icons.record_voice_over_rounded;
    } else if (t.contains('skill') ||
        t.contains('typing')) {
      return Icons.keyboard_rounded;
    } else if (t.contains('merit')) {
      return Icons.leaderboard_rounded;
    } else {
      return Icons.verified_rounded;
    }
  }

  // ── Dynamic Syllabus Tab from Firestore ───────────────
  Widget _buildSyllabusTab(
      Color catColor, Map<String, dynamic> syllabus) {

    if (syllabus.isEmpty) {
      return _buildNoDataWidget(
          'Syllabus will be updated soon!',
          'Check official notification for complete syllabus',
          Icons.menu_book_outlined,
          catColor);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Disclaimer box
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.amber.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: Colors.amber, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Always verify syllabus from official notification before starting preparation.',
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.amber.shade800),
                  ),
                ),
              ],
            ),
          ),

          ...syllabus.entries.map((entry) {
            final subjectName = entry.key;
            final dynamic rawValue = entry.value;

            // Handle String or List value
            List<String> topics = [];
            if (rawValue is String) {
              topics = [rawValue];
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
                    blurRadius: 8,
                    offset: const Offset(0, 4))],
              ),
              child: ExpansionTile(
                initiallyExpanded: true,
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: catColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.book_rounded,
                      color: catColor, size: 22),
                ),
                title: Text(subjectName,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                subtitle: Text(
                    topics.length == 1 ? 'Tap to expand' : '${topics.length} topics',
                    style: TextStyle(
                        fontSize: 12, color: catColor)),
                children: topics
                    .map((topic) => ListTile(
                  dense: true,
                  leading: Icon(
                      Icons.arrow_right_rounded,
                      color: catColor),
                  title: Text(topic.toString(),
                      style: const TextStyle(
                          fontSize: 13)),
                ))
                    .toList(),
              ),
            );
          }),
        ],
      ),
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
            Icon(icon, size: 72,
                color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF374151))),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFF9CA3AF))),
          ],
        ),
      ),
    );
  }

  Widget _buildPapersTab(String title, String category,
      Color catColor) {
    // Official previous year paper sources per category
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

    final sources = paperSources[category] ??
        paperSources['SSC']!;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Info banner
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: catColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: catColor.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline,
                  color: catColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tap any source below to view & download '
                      'official previous year papers.',
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: catColor,
                      height: 1.4),
                ),
              ),
            ],
          ),
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
                  blurRadius: 8,
                  offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    color: catColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                      Icons.picture_as_pdf_rounded,
                      color: catColor, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(paper['name']!,
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(
                                  0xFF1A1A2E))),
                      const SizedBox(height: 2),
                      Text(paper['desc']!,
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              color:
                              Colors.grey.shade500)),
                      const SizedBox(height: 4),
                      Text(paper['source']!,
                          style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: catColor,
                              fontWeight:
                              FontWeight.w600)),
                    ],
                  ),
                ),
                Icon(Icons.open_in_new_rounded,
                    color: catColor, size: 18),
              ],
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildSection(
      String title, IconData icon, Widget content) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary,
                    size: 22),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E))),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          Padding(
              padding: const EdgeInsets.all(16),
              child: content),
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
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E))),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String label, String value,
      IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplyButton(Color catColor, String jobId,
      String title, String organization, String category,
      String url) {
    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 12,
        bottom: 16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          // Mark as Applied button
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
                  color: _isApplied
                      ? const Color(0xFF10B981)
                      : Colors.white,
                  border: Border.all(
                      color: _isApplied
                          ? const Color(0xFF10B981)
                          : const Color(0xFF10B981)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    _isApplied ? 'Applied ✅' : 'Mark Applied',
                    style: TextStyle(
                        color: _isApplied
                            ? Colors.white
                            : const Color(0xFF10B981),
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Apply Now button
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: () => _openURL(context, url),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [
                        catColor,
                        catColor.withOpacity(0.8)
                      ]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(
                      color: catColor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6))],
                ),
                child: const Center(
                  child: Text('Apply Now →',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}