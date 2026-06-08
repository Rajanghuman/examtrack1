import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with SingleTickerProviderStateMixin {

  late TabController _tabController;
  String _searchQuery      = '';
  String _selectedCategory = 'All';
  bool _isLoading          = true;
  final TextEditingController _searchController =
  TextEditingController();

  List<Map<String, dynamic>> _results          = [];
  Set<String> _appliedJobTitles                = {};
  // title.toLowerCase() → full trackedJob data
  Map<String, Map<String, dynamic>> _trackedJobsMap = {};

  final List<String> _categories = [
    'All', 'Railway', 'SSC', 'Banking',
    'Police', 'Army', 'UPSC',
  ];

  static const Map<String, String> _officialLinks = {
    'SSC':     'https://ssc.gov.in/resultdetails',
    'Railway': 'https://www.rrbcdg.gov.in',
    'Banking': 'https://www.ibps.in',
    'Police':  'https://punjabpolice.gov.in',
    'Army':    'https://joinindianarmy.nic.in',
    'UPSC':    'https://upsc.gov.in/examinations/active-examinations',
    'Default': 'https://sarkariresult.com',
  };

  // No seed data — results only show when user applied AND result is declared
  static final List<Map<String, dynamic>> _seedResults = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // Declared + Pending
    _loadResults();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadResults() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('results')
          .orderBy('resultDate', descending: true)
          .get();
      final loaded = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();

      Set<String> applied = {};
      Map<String, Map<String, dynamic>> trackedMap = {};
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final tracked = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('trackedJobs')
            .get();
        for (final doc in tracked.docs) {
          final data =
          Map<String, dynamic>.from(doc.data());
          data['_docId'] = doc.id;
          final title = (data['title'] as String? ?? '')
              .toLowerCase();
          applied.add(title);
          trackedMap[title] = data;
        }
      }

      setState(() {
        _results          = loaded.isEmpty ? _seedResults : loaded;
        _appliedJobTitles = applied;
        _trackedJobsMap   = trackedMap;
        _isLoading        = false;
      });
    } catch (e) {
      print('Error loading results: $e');
      setState(() {
        _results   = _seedResults;
        _isLoading = false;
      });
    }
  }

  // ── Find matching tracked job ──────────────────────────
  Map<String, dynamic>? _getTrackedJob(
      Map<String, dynamic> result) {
    final name =
    (result['examName'] as String? ?? '').toLowerCase();
    for (final entry in _trackedJobsMap.entries) {
      if (name.contains(entry.key) ||
          entry.key.contains(name.split(' ').first)) {
        return entry.value;
      }
    }
    return null;
  }

  bool _userApplied(Map<String, dynamic> result) {
    final name =
    (result['examName'] as String? ?? '').toLowerCase();
    return _appliedJobTitles.any((t) =>
    name.contains(t) ||
        t.contains(name.split(' ').first));
  }

  List<Map<String, dynamic>> get _filtered {
    return _results.where((r) {
      final matchCat = _selectedCategory == 'All' ||
          r['category'] == _selectedCategory;
      final matchSearch = _searchQuery.isEmpty ||
          (r['examName'] as String? ?? '')
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          (r['org'] as String? ?? '')
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());
      return matchCat && matchSearch;
    }).toList();
  }

  // Only show declared results for jobs user applied to
  List<Map<String, dynamic>> get _declaredResults =>
      _filtered.where((r) =>
      r['status'] == 'declared' && _userApplied(r)).toList();
  // Pending = applied jobs where result not yet declared
  List<Map<String, dynamic>> get _pendingResults =>
      _filtered.where((r) =>
      r['status'] != 'declared' && _userApplied(r)).toList();

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'Railway': return const Color(0xFF1565C0);
      case 'SSC':     return const Color(0xFFE65100);
      case 'Banking': return const Color(0xFF6A1B9A);
      case 'Police':  return const Color(0xFF1B5E20);
      case 'Army':    return const Color(0xFF33691E);
      case 'UPSC':    return const Color(0xFF880E4F);
      default:        return const Color(0xFF1565C0);
    }
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'Railway': return Icons.train_rounded;
      case 'SSC':     return Icons.description_rounded;
      case 'Banking': return Icons.account_balance_rounded;
      case 'Police':  return Icons.local_police_rounded;
      case 'Army':    return Icons.military_tech_rounded;
      case 'UPSC':    return Icons.gavel_rounded;
      default:        return Icons.article_rounded;
    }
  }

  String _officialLink(Map<String, dynamic> result) {
    final url = result['resultUrl'] as String? ?? '';
    if (url.isNotEmpty) return url;
    final cat = result['category'] as String? ?? '';
    return _officialLinks[cat] ?? _officialLinks['Default']!;
  }

  String _formatNumber(int n) {
    if (n >= 100000)
      return '${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000)
      return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  Future<void> _openURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri,
          mode: LaunchMode.externalApplication);
    } else {
      _showToast('Unable to open link', success: false);
    }
  }

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

  // ── STEP 1: Show reg number + options ─────────────────
  void _checkRollNumber(Map<String, dynamic> result) {
    final tracked    = _getTrackedJob(result);
    final String regNo =
        tracked?['registrationNo'] as String? ?? '';
    final String userCat =
        tracked?['userCategory'] as String? ?? '';
    final bool hasMarks =
        (tracked?['marksObtained'] as num? ?? 0) > 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.search_rounded,
                color: Color(0xFF1565C0), size: 20),
            const SizedBox(width: 8),
            Text('Check Result',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(result['examName'] as String? ?? '',
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1A2E))),
            const SizedBox(height: 12),

            // Show saved reg number
            if (regNo.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0)
                      .withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF1565C0)
                          .withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(
                        Icons.confirmation_number_outlined,
                        color: Color(0xFF1565C0),
                        size: 18),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text('Your Registration No.',
                            style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: const Color(
                                    0xFF6B7280))),
                        Text(regNo,
                            style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: const Color(
                                    0xFF1565C0))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Show category
            if (userCat.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.category_outlined,
                        color: Colors.grey.shade500,
                        size: 18),
                    const SizedBox(width: 8),
                    Text('Category: $userCat',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            color:
                            const Color(0xFF374151))),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            Text(
              regNo.isNotEmpty
                  ? 'Use your registration number above on the official site to check your result.'
                  : 'Open the official result page, check your result, then come back to enter your marks.',
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF6B7280),
                  height: 1.5),
            ),

            // Already entered marks
            if (hasMarks) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981)
                      .withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.edit_outlined,
                        color: Color(0xFF10B981),
                        size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Marks saved: ${tracked!['marksObtained']}. Tap "Update Marks" to change.',
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: const Color(
                                0xFF10B981)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.poppins(
                    color: const Color(0xFF6B7280))),
          ),
          if (tracked != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _enterMarksDialog(result, tracked);
              },
              child: Text(
                hasMarks ? 'Update Marks' : 'Enter Marks',
                style: GoogleFonts.poppins(
                    color: const Color(0xFF10B981),
                    fontWeight: FontWeight.w600),
              ),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openURL(_officialLink(result));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Open Result Site',
                style: GoogleFonts.poppins(
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── STEP 2: Enter marks dialog ─────────────────────────
  void _enterMarksDialog(Map<String, dynamic> result,
      Map<String, dynamic> tracked) {
    final marksCtrl = TextEditingController(
        text: (tracked['marksObtained'] as num? ?? 0) > 0
            ? '${tracked['marksObtained']}'
            : '');
    final String userCat =
        tracked['userCategory'] as String? ?? 'General';
    final Map cutoffs =
        result['cutoffs'] as Map? ?? {};
    final num? cutoff = cutoffs[userCat] as num?;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.edit_rounded,
                color: Color(0xFF1565C0), size: 20),
            const SizedBox(width: 8),
            Text('Enter Your Marks',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(result['examName'] as String? ?? '',
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF6B7280))),
            const SizedBox(height: 16),
            TextField(
              controller: marksCtrl,
              keyboardType:
              const TextInputType.numberWithOptions(
                  decimal: true),
              decoration: InputDecoration(
                labelText: 'Marks Obtained',
                labelStyle:
                GoogleFonts.poppins(fontSize: 13),
                hintText: 'e.g. 142.5',
                prefixIcon: const Icon(
                    Icons.score_outlined,
                    color: Color(0xFF1565C0)),
                border: OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: Color(0xFF1565C0),
                        width: 2)),
              ),
            ),
            const SizedBox(height: 10),
            if (cutoff != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$userCat Cutoff:',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(
                                0xFF6B7280))),
                    Text('$cutoff',
                        style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(
                                0xFF1565C0))),
                  ],
                ),
              )
            else
              Text(
                'Cutoff for $userCat not announced yet.\nWe\'ll save your marks for comparison later.',
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                    height: 1.5),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.poppins(
                    color: const Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () async {
              final marks = num.tryParse(
                  marksCtrl.text.trim());
              if (marks == null) {
                _showToast('Please enter valid marks',
                    success: false);
                return;
              }
              Navigator.pop(ctx);
              await _saveMarksAndUpdateStatus(
                result:   result,
                tracked:  tracked,
                marks:    marks,
                cutoff:   cutoff,
                userCat:  userCat,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Save Marks',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── STEP 3: Save marks + update Job Tracker ───────────
  Future<void> _saveMarksAndUpdateStatus({
    required Map<String, dynamic> result,
    required Map<String, dynamic> tracked,
    required num marks,
    required num? cutoff,
    required String userCat,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final String docId = tracked['_docId'] as String;

      String newStatus;
      if (cutoff != null) {
        newStatus =
        marks >= cutoff ? 'Qualified ✅' : 'Not Qualified ❌';
      } else {
        newStatus = 'Result Entered';
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('trackedJobs')
          .doc(docId)
          .update({
        'marksObtained': marks,
        'status':        newStatus,
      });

      await _loadResults();

      if (cutoff != null) {
        _showResultDialog(
          marks:    marks,
          cutoff:   cutoff,
          userCat:  userCat,
          examName: result['examName'] as String? ?? '',
          qualified: marks >= cutoff,
        );
      } else {
        _showToast('Marks saved successfully');
      }
    } catch (e) {
      _showToast('Failed to save marks', success: false);
    }
  }

  // ── STEP 4: Qualified / Not Qualified dialog ──────────
  void _showResultDialog({
    required num marks,
    required num cutoff,
    required String userCat,
    required String examName,
    required bool qualified,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: qualified
                    ? const Color(0xFF10B981)
                    .withOpacity(0.1)
                    : const Color(0xFFEF4444)
                    .withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                qualified
                    ? Icons.emoji_events_rounded
                    : Icons.sentiment_dissatisfied_rounded,
                size: 44,
                color: qualified
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              qualified
                  ? 'Congratulations! 🎉'
                  : 'Better Luck Next Time',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: qualified
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(examName,
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF6B7280)),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment:
              MainAxisAlignment.spaceEvenly,
              children: [
                _resultStatBox(
                  'Your Score', '$marks',
                  qualified
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                ),
                _resultStatBox(
                  '$userCat Cutoff', '$cutoff',
                  const Color(0xFF1565C0),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              qualified
                  ? 'You scored $marks vs cutoff $cutoff. Your Job Tracker has been updated to "Qualified ✅"!'
                  : 'You scored $marks but needed $cutoff. Keep preparing — you\'ll crack it next time!',
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF6B7280),
                  height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: qualified
                    ? const Color(0xFF10B981)
                    : const Color(0xFF1565C0),
                shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(10)),
              ),
              child: Text('OK',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultStatBox(
      String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color)),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: const Color(0xFF6B7280))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          _buildHeader(),
          _buildSearchBar(),
          _buildCategoryChips(),
          _buildTabBar(),
          Expanded(
            child: _isLoading
                ? const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF1565C0)))
                : TabBarView(
              controller: _tabController,
              children: [
                _buildResultList(
                    _declaredResults, 'declared'),
                _buildResultList(
                    _pendingResults, 'pending'),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    final declaredCount  = _declaredResults.length;
    final upcomingCount  = _pendingResults.length;

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
                onTap: () =>
                    Navigator.pushReplacementNamed(
                        context, '/home'),
                child: const Icon(Icons.arrow_back,
                    color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text('Results',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              GestureDetector(
                onTap: _loadResults,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                    Colors.white.withOpacity(0.2),
                    borderRadius:
                    BorderRadius.circular(10),
                  ),
                  child: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _headerStat('$declaredCount', 'Declared'),
              const SizedBox(width: 24),
              _headerStat('$upcomingCount', 'Pending'),
              const SizedBox(width: 24),
              _headerStat(
                  '${_declaredResults.length + _pendingResults.length}', 'Applied'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700)),
        Text(label,
            style: GoogleFonts.poppins(
                color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: const Color(0xFF1565C0),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (v) =>
              setState(() => _searchQuery = v),
          decoration: InputDecoration(
            hintText: 'Search results...',
            hintStyle: GoogleFonts.poppins(
                color: const Color(0xFF9CA3AF),
                fontSize: 13),
            prefixIcon: const Icon(Icons.search,
                color: Color(0xFF9CA3AF)),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              child: const Icon(Icons.clear,
                  color: Color(0xFF9CA3AF)),
            )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(
        height: 38,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
              horizontal: 16),
          itemCount: _categories.length,
          itemBuilder: (context, i) {
            final cat = _categories[i];
            final selected = _selectedCategory == cat;
            return GestureDetector(
              onTap: () => setState(
                      () => _selectedCategory = cat),
              child: AnimatedContainer(
                duration:
                const Duration(milliseconds: 200),
                margin:
                const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF1565C0)
                      : Colors.transparent,
                  borderRadius:
                  BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF1565C0)
                        : const Color(0xFFD1D5DB),
                  ),
                ),
                child: Text(cat,
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: selected
                            ? Colors.white
                            : const Color(
                            0xFF6B7280))),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF1565C0),
        unselectedLabelColor: const Color(0xFF6B7280),
        indicatorColor: const Color(0xFF1565C0),
        indicatorWeight: 3,
        labelStyle: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
        GoogleFonts.poppins(fontSize: 13),
        tabs: [
          Tab(text:
          'Declared (${_declaredResults.length})'),
          Tab(text:
          'Pending (${_pendingResults.length})')
        ],
      ),
    );
  }

  Widget _buildResultList(
      List<Map<String, dynamic>> results, String type) {
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
                type == 'declared'
                    ? 'No Declared Results Yet'
                    : 'No Pending Results',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF374151))),
            const SizedBox(height: 8),
            Text(
              type == 'declared'
                  ? 'Results will appear here when you\napply for exams and results are declared.'
                  : type == 'pending'
                  ? 'No pending results. Apply for jobs\nfirst to track your results here.'
                  : 'No results found',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF6B7280),
                  height: 1.5),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => Navigator.pushNamed(
                  context, '/jobs'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Browse Jobs',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadResults,
      child: ListView.builder(
        padding:
        const EdgeInsets.fromLTRB(16, 16, 16, 20),
        itemCount: results.length,
        itemBuilder: (context, i) =>
            _buildResultCard(results[i]),
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> result) {
    final String category =
        result['category'] as String? ?? 'SSC';
    final String status =
        result['status'] as String? ?? 'upcoming';
    final Color catColor  = _categoryColor(category);
    final IconData catIcon = _categoryIcon(category);
    final bool applied    = _userApplied(result);
    final tracked         = _getTrackedJob(result);
    final Map cutoffs     = result['cutoffs'] as Map? ?? {};
    final List stages     = result['stages'] as List? ?? [];
    final int currentStage =
        result['currentStage'] as int? ?? 0;
    final int totalCandidates =
        result['totalCandidates'] as int? ?? 0;
    final int qualified =
        result['qualified'] as int? ?? 0;
    final num savedMarks =
        tracked?['marksObtained'] as num? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: applied
            ? Border.all(
            color: const Color(0xFF10B981)
                .withOpacity(0.4),
            width: 1.5)
            : null,
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: catColor.withOpacity(0.1),
                    borderRadius:
                    BorderRadius.circular(12),
                  ),
                  child: Icon(catIcon,
                      color: catColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        result['examName']
                        as String? ??
                            '',
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(
                                0xFF1A1A2E)),
                      ),
                      Text(
                        result['org'] as String? ?? '',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(
                                0xFF6B7280)),
                      ),
                      if (applied) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets
                                  .symmetric(
                                  horizontal: 8,
                                  vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(
                                    0xFF10B981)
                                    .withOpacity(0.1),
                                borderRadius:
                                BorderRadius.circular(
                                    6),
                              ),
                              child: Row(
                                mainAxisSize:
                                MainAxisSize.min,
                                children: [
                                  const Icon(
                                      Icons
                                          .check_circle_rounded,
                                      size: 11,
                                      color: Color(
                                          0xFF10B981)),
                                  const SizedBox(
                                      width: 4),
                                  Text('You Applied',
                                      style: GoogleFonts
                                          .poppins(
                                          fontSize:
                                          10,
                                          color: const Color(
                                              0xFF10B981),
                                          fontWeight:
                                          FontWeight
                                              .w600)),
                                ],
                              ),
                            ),
                            if (savedMarks > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets
                                    .symmetric(
                                    horizontal: 8,
                                    vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(
                                      0xFF1565C0)
                                      .withOpacity(0.1),
                                  borderRadius:
                                  BorderRadius
                                      .circular(6),
                                ),
                                child: Text(
                                    'Score: $savedMarks',
                                    style: GoogleFonts
                                        .poppins(
                                        fontSize:
                                        10,
                                        color: const Color(
                                            0xFF1565C0),
                                        fontWeight:
                                        FontWeight
                                            .w600)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: status == 'declared'
                        ? const Color(0xFF10B981)
                        .withOpacity(0.1)
                        : const Color(0xFFF59E0B)
                        .withOpacity(0.1),
                    borderRadius:
                    BorderRadius.circular(20),
                  ),
                  child: Text(
                    status == 'declared'
                        ? 'Declared'
                        : 'Pending',
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: status == 'declared'
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(
                height: 1, color: Color(0xFFF3F4F6)),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(child: _infoBox(
                    Icons.people_outline,
                    'Appeared',
                    _formatNumber(totalCandidates),
                    catColor)),
                const SizedBox(width: 8),
                Expanded(child: _infoBox(
                    Icons.check_circle_outline,
                    'Qualified',
                    _formatNumber(qualified),
                    const Color(0xFF10B981))),
                const SizedBox(width: 8),
                Expanded(child: _infoBox(
                    Icons.calendar_today_outlined,
                    status == 'declared'
                        ? 'Result Date'
                        : 'Expected',
                    result['resultDate']
                    as String? ??
                        'TBA',
                    catColor)),
              ],
            ),

            // Stages
            if (stages.isNotEmpty) ...[
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children:
                  List.generate(stages.length, (i) {
                    final bool done = i < currentStage;
                    final bool current =
                        i == currentStage;
                    return Row(
                      children: [
                        Container(
                          padding: const EdgeInsets
                              .symmetric(
                              horizontal: 10,
                              vertical: 5),
                          decoration: BoxDecoration(
                            color: done
                                ? const Color(0xFF10B981)
                                .withOpacity(0.1)
                                : current
                                ? catColor
                                .withOpacity(
                                0.1)
                                : const Color(
                                0xFFF3F4F6),
                            borderRadius:
                            BorderRadius.circular(
                                20),
                            border: Border.all(
                              color: done
                                  ? const Color(
                                  0xFF10B981)
                                  : current
                                  ? catColor
                                  : Colors
                                  .transparent,
                            ),
                          ),
                          child: Text(
                            '${done ? '✓ ' : current ? '▶ ' : ''}${stages[i]}',
                            style: TextStyle(
                              fontSize: 11,
                              color: done
                                  ? const Color(
                                  0xFF10B981)
                                  : current
                                  ? catColor
                                  : const Color(
                                  0xFF9CA3AF),
                              fontWeight: current
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (i < stages.length - 1)
                          const SizedBox(width: 4),
                      ],
                    );
                  }),
                ),
              ),
            ],

            // Cutoffs
            if (cutoffs.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildCutoffs(cutoffs, catColor,
                  savedMarks: savedMarks),
            ],

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _checkRollNumber(result),
                    icon: Icon(
                      applied
                          ? Icons.score_outlined
                          : Icons.search_rounded,
                      size: 16,
                    ),
                    label: Text(
                      applied
                          ? (savedMarks > 0
                          ? 'Update Marks'
                          : 'Enter Marks')
                          : 'Check Result',
                      style: GoogleFonts.poppins(
                          fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: catColor,
                      side: BorderSide(color: catColor),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(
                              10)),
                      padding:
                      const EdgeInsets.symmetric(
                          vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _openURL(_officialLink(result)),
                    icon: const Icon(
                        Icons.open_in_new_rounded,
                        size: 16,
                        color: Colors.white),
                    label: Text('Official Site',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: catColor,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(
                              10)),
                      padding:
                      const EdgeInsets.symmetric(
                          vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCutoffs(Map cutoffs, Color catColor,
      {num savedMarks = 0}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border:
        Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
            children: [
              Text('Category-wise Cutoffs',
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF374151))),
              if (savedMarks > 0)
                Text('Your Score: $savedMarks',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: catColor)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: cutoffs.entries
                .map<Widget>((entry) {
              final num cutoff = entry.value as num;
              final bool above = savedMarks > 0 &&
                  savedMarks >= cutoff;
              final bool below = savedMarks > 0 &&
                  savedMarks < cutoff;
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: savedMarks > 0
                      ? above
                      ? const Color(0xFF10B981)
                      .withOpacity(0.1)
                      : const Color(0xFFEF4444)
                      .withOpacity(0.08)
                      : const Color(0xFFF3F4F6),
                  borderRadius:
                  BorderRadius.circular(8),
                  border: Border.all(
                    color: savedMarks > 0
                        ? above
                        ? const Color(0xFF10B981)
                        .withOpacity(0.3)
                        : const Color(0xFFEF4444)
                        .withOpacity(0.2)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Column(
                  children: [
                    Text(entry.key,
                        style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: const Color(
                                0xFF6B7280))),
                    Text('$cutoff',
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: savedMarks > 0
                                ? above
                                ? const Color(
                                0xFF10B981)
                                : const Color(
                                0xFFEF4444)
                                : const Color(
                                0xFF1A1A2E))),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _infoBox(IconData icon, String label,
      String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(value,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color)),
          Text(label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 9,
                  color: const Color(0xFF6B7280))),
        ],
      ),
    );
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
          case 0: Navigator.pushReplacementNamed(
              context, '/home'); break;
          case 1: Navigator.pushReplacementNamed(
              context, '/jobs'); break;
          case 2: Navigator.pushReplacementNamed(
              context, '/current-affairs'); break;
          case 3: Navigator.pushReplacementNamed(
              context, '/saved'); break;
          case 4: Navigator.pushReplacementNamed(
              context, '/profile'); break;
        }
      },
      items: const [
        BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home'),
        BottomNavigationBarItem(
            icon: Icon(Icons.work_outline),
            activeIcon: Icon(Icons.work),
            label: 'Jobs'),
        BottomNavigationBarItem(
            icon: Icon(Icons.newspaper_outlined),
            activeIcon: Icon(Icons.newspaper),
            label: 'News'),
        BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_outline),
            activeIcon: Icon(Icons.bookmark),
            label: 'Saved'),
        BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile'),
      ],
    );
  }
}