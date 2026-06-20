import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/job_service.dart';
import 'dart:io';

class JobListingScreen extends StatefulWidget {
  const JobListingScreen({super.key});

  @override
  State<JobListingScreen> createState() =>
      _JobListingScreenState();
}

class _JobListingScreenState extends State<JobListingScreen> {
  String _selectedCategory    = 'All';
  String _searchQuery         = '';
  bool _showFilters           = false;
  String _selectedState       = 'All States';
  String _selectedQualification = 'All';
  String _sortBy              = 'Best Match';
  final TextEditingController _searchController =
  TextEditingController();

  final JobService _jobService = JobService();
  List<Map<String, dynamic>> _allJobs    = [];
  bool _isLoadingJobs                    = true;

  String _userQualification = '';
  String _userState         = '';
  List<String> _userCategories = [];
  bool _hasPreferences      = false;

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
    _loadJobs();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is String && args.isNotEmpty) {
      setState(() => _selectedCategory = args);
    }
  }

  Future<void> _loadUserPreferences() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          setState(() {
            _userQualification = data['qualification'] as String? ?? '';
            _userState = data['state'] as String? ?? '';
            final cats = data['preferredExams']
                ?? data['categories']
                ?? data['preferredCategories']
                ?? [];
            _userCategories = List<String>.from(cats);
            _hasPreferences = true;
          });
        }
      }
    } catch (e) {
      print('Error loading preferences: $e');
    }
  }

  Future<void> _loadJobs() async {
    setState(() => _isLoadingJobs = true);
    try {
      final jobs = await _jobService.getAllJobs();
      setState(() {
        _allJobs = jobs;
        _isLoadingJobs = false;
      });
    } on SocketException {
      setState(() => _isLoadingJobs = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No internet connection. Please check your network.',
                style: GoogleFonts.poppins()),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadJobs,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error loading jobs: $e');
      setState(() => _isLoadingJobs = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load jobs. Please try again.',
                style: GoogleFonts.poppins()),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadJobs,
            ),
          ),
        );
      }
    }
  }

  int _calculateDaysLeft(dynamic lastDate) {
    try {
      if (lastDate == null) return 0;
      final str = lastDate.toString().trim();
      if (str.isEmpty) return 0;
      if (str.toUpperCase().contains('TBA') ||
          str.toUpperCase().contains('TO BE ANNOUNCED') ||
          str.toUpperCase().contains('NOT ANNOUNCED')) return 999;
      if (str.toUpperCase().contains('CLOSED') ||
          str.toUpperCase().contains('CLOSE')) return -1;

      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(str)) {
        final parts = str.split('-');
        final date = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        return date.difference(DateTime.now()).inDays;
      }

      const months = {
        'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4,
        'may': 5, 'jun': 6, 'jul': 7, 'aug': 8,
        'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
        'january': 1, 'february': 2, 'march': 3, 'april': 4,
        'june': 6, 'july': 7, 'august': 8, 'september': 9,
        'october': 10, 'november': 11, 'december': 12,
      };
      // Clean date string — remove time, brackets, notes
      // Handles: "14 Jun 2026 (11:59 PM)", "11 Jun 2026 — EXTENDED", "29 Jun 2026 (17:00 hrs)"
      String cleaned = str;
      // Remove content in brackets
      cleaned = cleaned.replaceAll(RegExp(r'\(.*?\)'), '');
      // Remove everything after em-dash
      final dashIdx = cleaned.indexOf('—');
      if (dashIdx > 0) cleaned = cleaned.substring(0, dashIdx);
      // Keep only letters, numbers, spaces
      cleaned = cleaned.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), ' ').trim();
      // Collapse multiple spaces
      while (cleaned.contains('  ')) cleaned = cleaned.replaceAll('  ', ' ');

      final parts2 = cleaned.trim().split(' ').where((p) => p.isNotEmpty).toList();
      if (parts2.length >= 3) {
        final day   = int.tryParse(parts2[0]) ?? 0;
        final mStr  = parts2[1].toLowerCase();
        final month = months[mStr.length >= 3 ? mStr.substring(0, 3) : mStr] ?? 0;
        final year  = int.tryParse(parts2[2]) ?? 0;
        if (day > 0 && month > 0 && year > 0) {
          final date = DateTime(year, month, day);
          return date.difference(DateTime.now()).inDays;
        }
      }

      if (parts2.length == 2) {
        final mStr  = parts2[0].toLowerCase();
        final month = months[mStr.length >= 3 ? mStr.substring(0, 3) : mStr] ?? 0;
        final year  = int.tryParse(parts2[1]) ?? 0;
        if (month > 0 && year > 0) {
          final date = DateTime(year, month + 1, 0);
          return date.difference(DateTime.now()).inDays;
        }
      }

      return 0;
    } catch (e) {
      return 0;
    }
  }

  int _qualRank(String q) {
    const Map<String, int> rankMap = {
      '8th Pass': 0,
      '10th Pass': 1, '10th Pass (Matric)': 1,
      '12th Pass': 2, '12th Pass (Inter)': 2,
      'ITI': 3, 'Diploma': 3,
      'Diploma (Engineering)': 3, 'Diploma (Non-Engineering)': 3,
      'Graduate': 4,
      'B.A (Arts)': 4, 'B.Sc (Science)': 4, 'B.Com (Commerce)': 4,
      'B.Tech / B.E (Engineering)': 4, 'B.C.A (Computer)': 4,
      'B.B.A (Business)': 4, 'B.Ed (Teaching)': 4, 'B.Ed': 4,
      'B.Sc Nursing': 4, 'B.Pharma': 4, 'B.Sc Agriculture': 4,
      'BDS (Dental)': 4, 'MBBS (Medical)': 4, 'MBBS': 4,
      'LLB (Law)': 4, 'LLB': 4, 'B.Arch (Architecture)': 4,
      'B.Sc (IT)': 4, 'Other Graduate': 4,
      'Post Graduate': 5,
      'M.A (Arts)': 5, 'M.Sc (Science)': 5, 'M.Com (Commerce)': 5,
      'M.Tech / M.E (Engineering)': 5, 'M.C.A (Computer)': 5,
      'M.B.A (Business)': 5, 'M.Ed (Teaching)': 5, 'M.Sc Nursing': 5,
      'M.Pharma': 5, 'LLM (Law)': 5, 'PGDM': 5,
      'Other Post Graduate': 5, 'Ph.D': 6,
    };
    return rankMap[q] ?? -1;
  }

  bool _matchesQualification(Map<String, dynamic> job) {
    if (_userQualification.isEmpty) return false;
    final jobQual = job['qualification'] as String? ?? '';
    final userRank = _qualRank(_userQualification);
    final jobRank  = _qualRank(jobQual);
    return userRank >= jobRank && jobRank != -1;
  }

  bool _matchesState(Map<String, dynamic> job) {
    if (_userState.isEmpty) return false;
    final jobState = job['state'] as String? ?? '';
    return jobState == _userState || jobState == 'All India';
  }

  bool _matchesCategory(Map<String, dynamic> job) {
    if (_userCategories.isEmpty) return false;
    final jobCat = job['category'] as String? ?? '';
    return _userCategories.contains(jobCat);
  }

  int _relevanceScore(Map<String, dynamic> job) {
    int score = 0;
    if (_matchesState(job)) score += 5;
    if (_matchesCategory(job)) score += 4;
    if (_matchesQualification(job)) score += 3;
    if (job['isNew'] == true) score += 2;
    final daysLeft = _calculateDaysLeft(job['lastDate']);
    if (daysLeft > 0 && daysLeft <= 15) score += 3;
    else if (daysLeft > 0 && daysLeft <= 30) score += 1;
    if ((job['state'] as String? ?? '') == 'All India') score += 1;
    return score;
  }

  // ── Calculate Job Match Score (0-100%) ────────────────
  int _calculateMatchScore(Map<String, dynamic> job) {
    if (!_hasPreferences) return 0;
    int score = 0;
    int total = 0;

    // 1. Qualification match (40 points)
    total += 40;
    final jobQual  = job['qualification'] as String? ?? '';
    final userRank = _qualRank(_userQualification);
    final jobRank  = _qualRank(jobQual);
    if (jobRank != -1 && userRank >= jobRank) score += 40;
    else if (jobRank != -1 && userRank == jobRank - 1) score += 20;

    // 2. State match (30 points)
    total += 30;
    final jobState = job['state'] as String? ?? '';
    if (jobState == 'All India') score += 30;
    else if (jobState == _userState) score += 30;
    else if (_userState.isEmpty) score += 15;

    // 3. Category preference (20 points)
    total += 20;
    final jobCat = job['category'] as String? ?? '';
    if (_userCategories.contains(jobCat)) score += 20;
    else if (_userCategories.isEmpty) score += 10;

    // 4. Deadline not passed (10 points)
    total += 10;
    final daysLeft = _calculateDaysLeft(job['lastDate']);
    if (daysLeft > 0) score += 10;

    return total > 0 ? ((score / total) * 100).round() : 0;
  }

  // ── Match score color ──────────────────────────────────
  Color _matchScoreColor(int score) {
    if (score >= 80) return const Color(0xFF10B981); // green
    if (score >= 60) return const Color(0xFF1565C0); // blue
    if (score >= 40) return const Color(0xFFF59E0B); // orange
    return const Color(0xFF9CA3AF);                  // grey
  }

  // ── Match score label ──────────────────────────────────
  String _matchScoreLabel(int score) {
    if (score >= 80) return 'Excellent Match';
    if (score >= 60) return 'Good Match';
    if (score >= 40) return 'Fair Match';
    return 'Low Match';
  }

  final List<String> _categories = [
    'All', 'Railway', 'Police', 'Banking', 'SSC',
    'Army', 'Teaching', 'Health', 'UPSC'
  ];

  final List<String> _states = [
    'All States', 'Punjab', 'Haryana',
    'Himachal Pradesh', 'Delhi', 'UP', 'All India'
  ];

  final List<String> _qualifications = [
    'All', '8th Pass', '10th Pass', '12th Pass',
    'ITI', 'Diploma', 'Graduate', 'Post Graduate', 'Ph.D'
  ];

  final List<String> _sortOptions = [
    'Best Match', 'Newest First',
    'Deadline Soon', 'Most Vacancies', 'Least Fee'
  ];

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

  List<Map<String, dynamic>> get _filteredJobs {
    List<Map<String, dynamic>> jobs = List.from(_allJobs);
    if (_selectedCategory != 'All') {
      jobs = jobs.where((j) => j['category'] == _selectedCategory).toList();
    }
    if (_selectedState != 'All States') {
      jobs = jobs.where((j) =>
      j['state'] == _selectedState || j['state'] == 'All India').toList();
    }
    if (_selectedQualification != 'All') {
      jobs = jobs.where((j) =>
      j['qualification'] == _selectedQualification).toList();
    }
    if (_searchQuery.isNotEmpty) {
      jobs = jobs.where((j) =>
      (j['title'] as String? ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (j['organization'] as String? ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (j['department'] as String? ?? '').toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    switch (_sortBy) {
      case 'Best Match':
        jobs.sort((a, b) => _relevanceScore(b).compareTo(_relevanceScore(a)));
        break;
      case 'Deadline Soon':
        jobs.sort((a, b) =>
            _calculateDaysLeft(a['lastDate']).compareTo(_calculateDaysLeft(b['lastDate'])));
        break;
      case 'Most Vacancies':
        jobs.sort((a, b) {
          final aV = (a['vacancies'] ?? a['posts'] ?? 0);
          final bV = (b['vacancies'] ?? b['posts'] ?? 0);
          final aInt = aV is int ? aV : int.tryParse(aV.toString()) ?? 0;
          final bInt = bV is int ? bV : int.tryParse(bV.toString()) ?? 0;
          return bInt.compareTo(aInt);
        });
        break;
      case 'Least Fee':
        jobs.sort((a, b) =>
            ((a['fee'] ?? 0) as int).compareTo((b['fee'] ?? 0) as int));
        break;
      default:
        jobs.sort((a, b) {
          if (a['isNew'] == b['isNew']) return 0;
          return (a['isNew'] == true) ? -1 : 1;
        });
    }
    return jobs;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jobs      = _filteredJobs;
    final newCount  = _allJobs.where((j) => j['isNew'] == true).length;
    final soonCount = _allJobs.where((j) =>
    _calculateDaysLeft(j['lastDate']) <= 15 &&
        _calculateDaysLeft(j['lastDate']) > 0).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          _buildHeader(newCount, soonCount),
          _buildSearchBar(),
          _buildCategoryChips(),
          _buildStateChips(),
          if (_hasPreferences && _sortBy == 'Best Match' && _selectedCategory == 'All')
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.person_outlined, color: Color(0xFF1565C0), size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  '✨ Showing jobs matched to your profile',
                  style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF1565C0)),
                )),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isLoadingJobs ? 'Loading...' : '${jobs.length} jobs found',
                  style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF6B7280), fontWeight: FontWeight.w500),
                ),
                GestureDetector(
                  onTap: _showSortDialog,
                  child: Row(children: [
                    Text(_sortBy, style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF1565C0), fontWeight: FontWeight.w600)),
                    const Icon(Icons.arrow_drop_down, color: Color(0xFF1565C0)),
                  ]),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoadingJobs
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0)))
                : jobs.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _loadJobs,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: jobs.length,
                itemBuilder: (context, index) => _buildJobCard(jobs[index]),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  void _showSortDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Sort By', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          ..._sortOptions.map((opt) => ListTile(
            title: Text(opt, style: GoogleFonts.poppins(fontSize: 14)),
            leading: Icon(
              opt == 'Best Match' ? Icons.person_outlined :
              opt == 'Newest First' ? Icons.new_releases_outlined :
              opt == 'Deadline Soon' ? Icons.timer_outlined :
              opt == 'Most Vacancies' ? Icons.people_outlined :
              Icons.money_off_outlined,
              color: _sortBy == opt ? const Color(0xFF1565C0) : Colors.grey,
            ),
            trailing: _sortBy == opt ? const Icon(Icons.check, color: Color(0xFF1565C0)) : null,
            onTap: () {
              setState(() => _sortBy = opt);
              Navigator.pop(ctx);
            },
          )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHeader(int newCount, int soonCount) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16, right: 16, bottom: 16,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            GestureDetector(
              onTap: () => Navigator.pushReplacementNamed(context, '/home'),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedCategory == 'All' ? 'All Jobs' : '$_selectedCategory Jobs',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text('${_allJobs.length} total jobs',
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
              ],
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _showFilters = !_showFilters),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _showFilters ? Colors.white : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.filter_list_rounded,
                    color: _showFilters ? const Color(0xFF1565C0) : Colors.white, size: 22),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _headerChip(Icons.fiber_new_rounded, '$newCount New', const Color(0xFF10B981)),
            const SizedBox(width: 10),
            _headerChip(Icons.timer_outlined, '$soonCount Closing Soon', const Color(0xFFF59E0B)),
            if (_hasPreferences) ...[
              const SizedBox(width: 10),
              _headerChip(Icons.person_rounded, 'Personalised', const Color(0xFF1565C0)),
            ],
          ]),
        ],
      ),
    );
  }

  Widget _headerChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        Icon(icon, color: Colors.white, size: 14),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: const Color(0xFF1565C0),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        style: GoogleFonts.poppins(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search jobs...',
          hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF)),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
            onTap: () { _searchController.clear(); setState(() => _searchQuery = ''); },
            child: const Icon(Icons.clear, color: Color(0xFF9CA3AF)),
          )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: _categories.map((cat) {
            final isSelected = _selectedCategory == cat;
            final color = cat == 'All' ? const Color(0xFF1565C0) : _categoryColor(cat);
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? color : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? color : Colors.grey.shade200),
                ),
                child: Row(children: [
                  if (cat != 'All') ...[
                    Icon(_categoryIcon(cat), color: isSelected ? Colors.white : color, size: 14),
                    const SizedBox(width: 4),
                  ],
                  Text(cat, style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  )),
                ]),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStateChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: SizedBox(
        height: 36,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _states.length,
          itemBuilder: (context, i) {
            final state   = _states[i];
            final selected = _selectedState == state;
            return GestureDetector(
              onTap: () => setState(() => _selectedState = state),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF1565C0) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: selected ? const Color(0xFF1565C0) : const Color(0xFFD1D5DB)),
                ),
                child: Text(
                  state == 'All States' ? '🗺 All' : state,
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: selected ? Colors.white : const Color(0xFF6B7280)),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final String title    = job['title'] as String? ?? '';
    final String org      = (job['organization'] ?? job['department'] ?? '') as String;
    final String category = job['category'] as String? ?? '';
    final dynamic vacRaw  = job['vacancies'] ?? job['posts'] ?? 0;
    final int vacancies   = vacRaw is int ? vacRaw : int.tryParse(vacRaw.toString()) ?? 0;
    final dynamic feeRaw  = job['fee'] ?? 0;
    final int fee         = feeRaw is int ? feeRaw : int.tryParse(feeRaw.toString()) ?? 0;
    final String salary   = job['salary'] as String? ?? '';
    final String lastDate = job['lastDate'] as String? ?? '';
    final String state    = job['state'] as String? ?? '';
    final bool isNew      = job['isNew'] == true;
    final Color color     = _categoryColor(category);
    final bool isMatch    = _hasPreferences &&
        (_matchesQualification(job) || _matchesState(job) || _matchesCategory(job));
    final int matchScore  = _hasPreferences ? _calculateMatchScore(job) : 0;
    final Color matchColor = _matchScoreColor(matchScore);

    // Application fee display
    final String appFee = job['applicationFee'] as String? ?? '';
    final bool isFree   = fee == 0 && appFee.toLowerCase().contains('nil') ||
        fee == 0 && appFee.isEmpty;



    // Shorten salary for display
    String salaryDisplay = salary;
    if (salary.length > 22) {
      salaryDisplay = salary.substring(0, 20) + '..';
    }

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context, '/job-detail',
        arguments: Map<String, dynamic>.from(job),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isMatch
              ? Border.all(color: const Color(0xFF1565C0).withOpacity(0.3), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          children: [
            if (isMatch)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withOpacity(0.08),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(children: [
                  const Icon(Icons.person_rounded, color: Color(0xFF1565C0), size: 12),
                  const SizedBox(width: 4),
                  Text('Matches your profile',
                      style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF1565C0), fontWeight: FontWeight.w600)),
                ]),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_categoryIcon(category), color: color, size: 22),
                      ),
                      const SizedBox(width: 12),
                      // ── FIXED: title and org with overflow handling ──
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1A1A2E),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              org,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (_calculateDaysLeft(lastDate) > 0 && _calculateDaysLeft(lastDate) < 999) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _calculateDaysLeft(lastDate) <= 7
                                    ? const Color(0xFFEF4444).withOpacity(0.12)
                                    : const Color(0xFFF59E0B).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_calculateDaysLeft(lastDate)} days left',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _calculateDaysLeft(lastDate) <= 7
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFFF59E0B),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          if (isNew) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('NEW',
                                  style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF10B981), fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),

                  // ── Match Score Bar ──────────────────
                  if (_hasPreferences && matchScore > 0) ...[
                    Row(
                      children: [
                        Text('Match: ',
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: const Color(0xFF6B7280))),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: matchScore / 100,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(matchColor),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('$matchScore%',
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: matchColor)),
                        const SizedBox(width: 4),
                        Text(_matchScoreLabel(matchScore),
                            style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: matchColor)),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  // ── FIXED: info chips with overflow handling ──
                  Row(
                    children: [
                      Flexible(
                        child: _infoChip(Icons.people_outline,
                            vacancies == 0 ? 'N/A' : '$vacancies Posts'),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: _infoChip(Icons.currency_rupee_outlined, salaryDisplay),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: _infoChip(Icons.location_on_outlined, state),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          lastDate.isEmpty || lastDate.toLowerCase().contains('tba')
                              ? 'Last Date: Not Announced'
                              : lastDate.toLowerCase().contains('closed')
                              ? 'Application Closed'
                              : 'Last Date: $lastDate',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey.shade500),
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            fee == 0 ? 'Free' : '₹$fee fee',
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: fee == 0 ? const Color(0xFF10B981) : Colors.grey.shade500,
                                fontWeight: fee == 0 ? FontWeight.w600 : FontWeight.normal),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(category,
                                style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF374151)),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.work_off_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No jobs found!', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
          const SizedBox(height: 8),
          Text('Try changing your filters', style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF9CA3AF))),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _selectedCategory    = 'All';
                _selectedState       = 'All States';
                _selectedQualification = 'All';
                _searchQuery         = '';
                _searchController.clear();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Clear Filters', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: 1,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF1565C0),
      unselectedItemColor: const Color(0xFF9CA3AF),
      selectedLabelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11),
      onTap: (i) {
        switch (i) {
          case 0: Navigator.pushReplacementNamed(context, '/home'); break;
          case 1: break;
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