import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class AdmitCardScreen extends StatefulWidget {
  const AdmitCardScreen({super.key});

  @override
  State<AdmitCardScreen> createState() => _AdmitCardScreenState();
}

class _AdmitCardScreenState extends State<AdmitCardScreen>
    with SingleTickerProviderStateMixin {

  late TabController _tabController;
  String _searchQuery     = '';
  String _selectedCategory = 'All';
  bool _isLoading          = true;
  final TextEditingController _searchController =
  TextEditingController();

  // Loaded from Firestore
  List<Map<String, dynamic>> _admitCards = [];
  // Titles of jobs user has applied to (from trackedJobs)
  Set<String> _appliedJobTitles = {};

  final List<String> _categories = [
    'All', 'Railway', 'SSC', 'Banking',
    'Police', 'Army', 'UPSC',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAdmitCards();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Load admit cards + user's applied jobs ────────────
  Future<void> _loadAdmitCards() async {
    setState(() => _isLoading = true);
    try {
      // Load admit cards
      final snapshot = await FirebaseFirestore.instance
          .collection('admitCards')
          .orderBy('examDate')
          .get();

      final cards = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Load user's applied job titles from trackedJobs
      Set<String> appliedTitles = {};
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final trackedSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('trackedJobs')
            .get();
        appliedTitles = trackedSnap.docs
            .map((d) =>
            (d.data()['title'] as String? ?? '')
                .toLowerCase())
            .toSet();
      }

      setState(() {
        _admitCards      = cards.isEmpty ? _seedAdmitCards : cards;
        _appliedJobTitles = appliedTitles;
        _isLoading       = false;
      });
    } catch (e) {
      setState(() {
        _admitCards = _seedAdmitCards;
        _isLoading  = false;
      });
    }
  }

  // ── Check if user applied for this exam ───────────────
  bool _userApplied(Map<String, dynamic> card) {
    final examName =
    (card['examName'] as String? ?? '').toLowerCase();
    // Match if any applied job title is contained
    // in the exam name or vice versa
    return _appliedJobTitles.any((title) =>
    examName.contains(title) ||
        title.contains(examName.split(' ').first));
  }

  // ── Seed data (shown until you add real data to Firestore)
  static final List<Map<String, dynamic>> _seedAdmitCards = [
    {
      'id': 'ac1',
      'examName': 'RRB NTPC CBT 1 2026',
      'org': 'Railway Recruitment Board',
      'category': 'Railway',
      'examDate': '15 Aug 2026',
      'releaseDate': '01 Aug 2026',
      'status': 'upcoming',
      'daysToRelease': 64,
      'daysToExam': 78,
      'examTime': '10:00 AM - 12:00 PM',
      'admitCardUrl': 'https://www.rrbcdg.gov.in',
      'instructions': [
        'Carry original photo ID proof',
        'Reach exam center 30 min early',
        'No mobile phones allowed',
        'Blue/Black ball pen only',
      ],
    },
    {
      'id': 'ac2',
      'examName': 'SSC CGL Tier 1 2026',
      'org': 'Staff Selection Commission',
      'category': 'SSC',
      'examDate': '01 Sep 2026',
      'releaseDate': '20 Aug 2026',
      'status': 'upcoming',
      'daysToRelease': 83,
      'daysToExam': 95,
      'examTime': '09:00 AM - 11:00 AM',
      'admitCardUrl': 'https://ssc.gov.in',
      'instructions': [
        'Carry colour printout of admit card',
        'One passport size photo required',
        'Aadhar card mandatory',
        'No calculator allowed',
      ],
    },
    {
      'id': 'ac3',
      'examName': 'IBPS PO Prelims 2026',
      'org': 'Institute of Banking Personnel',
      'category': 'Banking',
      'examDate': '05 Oct 2026',
      'releaseDate': '25 Sep 2026',
      'status': 'upcoming',
      'daysToRelease': 119,
      'daysToExam': 129,
      'examTime': '08:00 AM - 09:00 AM',
      'admitCardUrl': 'https://www.ibps.in',
      'instructions': [
        'Valid photo ID mandatory',
        'Reach 45 min before exam',
        'Rough sheet will be provided',
        'No watches allowed inside hall',
      ],
    },
    {
      'id': 'ac4',
      'examName': 'Punjab Police Constable 2026',
      'org': 'Punjab Police Department',
      'category': 'Police',
      'examDate': '20 Sep 2026',
      'releaseDate': '10 Sep 2026',
      'status': 'available',
      'daysToRelease': 0,
      'daysToExam': 114,
      'examTime': '10:00 AM - 12:00 PM',
      'admitCardUrl': 'https://punjabpolice.gov.in',
      'instructions': [
        'Carry original Aadhar card',
        'Wear light comfortable clothes',
        'Sports shoes allowed',
        'Reach center 1 hour early',
      ],
    },
    {
      'id': 'ac5',
      'examName': 'SSC CHSL Tier 1 2025',
      'org': 'Staff Selection Commission',
      'category': 'SSC',
      'examDate': '15 Nov 2025',
      'releaseDate': '01 Nov 2025',
      'status': 'expired',
      'daysToRelease': 0,
      'daysToExam': 0,
      'examTime': '10:00 AM - 12:00 PM',
      'admitCardUrl': 'https://ssc.gov.in',
      'instructions': [
        'Carry original photo ID proof',
        'Colour printout mandatory',
      ],
    },
    {
      'id': 'ac6',
      'examName': 'UPSC CSE Prelims 2026',
      'org': 'Union Public Service Commission',
      'category': 'UPSC',
      'examDate': '25 May 2026',
      'releaseDate': '10 May 2026',
      'status': 'expired',
      'daysToRelease': 0,
      'daysToExam': 0,
      'examTime': '09:30 AM - 11:30 AM',
      'admitCardUrl': 'https://upsconline.nic.in',
      'instructions': [
        'Two admit card copies needed',
        'Ball pen and pencil allowed',
        'No electronic devices',
      ],
    },
  ];

  // ── Filtering ──────────────────────────────────────────
  List<Map<String, dynamic>> get _filtered {
    return _admitCards.where((c) {
      final matchCat = _selectedCategory == 'All' ||
          c['category'] == _selectedCategory;
      final matchSearch = _searchQuery.isEmpty ||
          (c['examName'] as String? ?? '')
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          (c['org'] as String? ?? '')
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());
      return matchCat && matchSearch;
    }).toList();
  }

  List<Map<String, dynamic>> get _availableCards =>
      // Only show available cards for jobs user applied to
  _filtered
      .where((c) =>
  c['status'] == 'available' && _userApplied(c))
      .toList();
  List<Map<String, dynamic>> get _upcomingCards =>
      _filtered.where((c) => c['status'] == 'upcoming')
          .toList();
  List<Map<String, dynamic>> get _expiredCards =>
      _filtered.where((c) => c['status'] == 'expired')
          .toList();

  // ── Helpers ────────────────────────────────────────────
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

  Future<void> _openURL(String url) async {
    if (url.isEmpty) {
      _showToast('Link not available', success: false);
      return;
    }
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

  // ── Save reminder to Firestore ─────────────────────────
  Future<void> _setReminder(Map<String, dynamic> card) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showToast('Please sign in to continue', success: false);
        return;
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .add({
        'title': 'Admit Card Reminder 📄',
        'body':
        'Admit card for ${card['examName']} releases on ${card['releaseDate']}. Stay alert!',
        'type':        'Admit Cards',
        'isRead':      false,
        'isImportant': true,
        'createdAt':   FieldValue.serverTimestamp(),
      });
      _showToast('Reminder saved successfully');
    } catch (e) {
      _showToast('Failed to set reminder', success: false);
    }
  }

  // ── Download — opens official website ─────────────────
  void _downloadAdmitCard(Map<String, dynamic> card) {
    final url = card['admitCardUrl'] as String? ?? '';
    if (url.isEmpty) {
      _showToast('Official link not available yet',
          success: false);
      return;
    }
    _openURL(url);
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
                _buildCardList(
                    _availableCards, 'available'),
                _buildCardList(
                    _upcomingCards, 'upcoming'),
                _buildCardList(
                    _expiredCards, 'expired'),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    final availableCount = _admitCards
        .where((c) => c['status'] == 'available').length;
    final upcomingCount = _admitCards
        .where((c) => c['status'] == 'upcoming').length;

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
              Text('Admit Cards',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              GestureDetector(
                onTap: _loadAdmitCards,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.refresh_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
              if (availableCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$availableCount Ready',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _headerStat(availableCount.toString(),
                  'Available', const Color(0xFF10B981)),
              const SizedBox(width: 20),
              _headerStat(upcomingCount.toString(),
                  'Upcoming', Colors.white70),
              const SizedBox(width: 20),
              _headerStat(_admitCards.length.toString(),
                  'Total', Colors.white60),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerStat(
      String value, String label, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: GoogleFonts.poppins(
                color: color,
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
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8)
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (v) =>
              setState(() => _searchQuery = v),
          decoration: InputDecoration(
            hintText: 'Search exam name or organization...',
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
          padding:
          const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _categories.length,
          itemBuilder: (context, i) {
            final cat = _categories[i];
            final selected = _selectedCategory == cat;
            return GestureDetector(
              onTap: () =>
                  setState(() => _selectedCategory = cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF1565C0)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
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
                            : const Color(0xFF6B7280))),
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
          Tab(text: 'Available (${_availableCards.length})'),
          Tab(text: 'Upcoming (${_upcomingCards.length})'),
          Tab(text: 'Past (${_expiredCards.length})'),
        ],
      ),
    );
  }

  Widget _buildCardList(
      List<Map<String, dynamic>> cards, String type) {
    if (cards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'available'
                  ? Icons.how_to_reg_outlined
                  : Icons.article_outlined,
              size: 72,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              type == 'available'
                  ? 'No Admit Cards Yet'
                  : 'No admit cards here',
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF374151)),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 32),
              child: Text(
                type == 'available'
                    ? 'Admit cards will appear here once you apply for a job and the card is released by the organization.'
                    : type == 'upcoming'
                    ? 'No upcoming admit cards found'
                    : 'No past admit cards found',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFF6B7280),
                    height: 1.5),
              ),
            ),
            if (type == 'available') ...[
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
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAdmitCards,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        itemCount: cards.length,
        itemBuilder: (context, i) =>
            _buildAdmitCard(cards[i]),
      ),
    );
  }

  Widget _buildAdmitCard(Map<String, dynamic> card) {
    final String status =
        card['status'] as String? ?? 'upcoming';
    final String category =
        card['category'] as String? ?? 'SSC';
    final Color catColor = _categoryColor(category);
    final IconData catIcon = _categoryIcon(category);

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (status) {
      case 'available':
        statusColor = const Color(0xFF10B981);
        statusLabel = 'Download Now';
        statusIcon  = Icons.download_outlined;
        break;
      case 'upcoming':
        statusColor = const Color(0xFFF59E0B);
        statusLabel = 'Coming Soon';
        statusIcon  = Icons.schedule_outlined;
        break;
      default:
        statusColor = const Color(0xFF6B7280);
        statusLabel = 'Expired';
        statusIcon  = Icons.history_outlined;
    }

    final instructions =
    (card['instructions'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final bool applied = _userApplied(card);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == 'available'
              ? const Color(0xFF10B981).withOpacity(0.4)
              : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Padding(
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
                            card['examName'] as String? ??
                                '',
                            style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(
                                    0xFF1A1A2E)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            card['org'] as String? ?? '',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: const Color(
                                    0xFF6B7280)),
                          ),
                          if (applied) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981)
                                    .withOpacity(0.1),
                                borderRadius:
                                BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                      Icons.check_circle_rounded,
                                      size: 11,
                                      color: Color(0xFF10B981)),
                                  const SizedBox(width: 4),
                                  Text('You Applied',
                                      style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          color: const Color(
                                              0xFF10B981),
                                          fontWeight:
                                          FontWeight.w600)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius:
                        BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon,
                              size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(statusLabel,
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: statusColor,
                                  fontWeight:
                                  FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(
                    height: 1,
                    color: Color(0xFFF3F4F6)),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _infoRow(
                        Icons.event_outlined,
                        'Exam Date',
                        card['examDate'] as String? ??
                            'TBA',
                      ),
                    ),
                    Expanded(
                      child: _infoRow(
                        Icons.download_outlined,
                        status == 'available'
                            ? 'Released On'
                            : 'Release Date',
                        status == 'available' ||
                            status == 'expired'
                            ? card['releaseDate']
                        as String? ??
                            'N/A'
                            : 'In ${card['daysToRelease']} days',
                      ),
                    ),
                  ],
                ),

                // Upcoming — countdown
                if (status == 'upcoming') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _countdownBox(
                          '${card['daysToRelease'] ?? '?'}',
                          'Days to Release',
                          const Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _countdownBox(
                          '${card['daysToExam'] ?? '?'}',
                          'Days to Exam',
                          const Color(0xFF1565C0),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _countdownBox(
                          card['examTime'] as String? ??
                              'TBA',
                          'Exam Time',
                          const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Available/expired — instructions + download
          if (status == 'available' ||
              status == 'expired') ...[
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  if (instructions.isNotEmpty)
                    Theme(
                      data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding:
                        const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 0),
                        title: Text(
                            'Important Instructions',
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(
                                    0xFF374151))),
                        leading: const Icon(
                            Icons.info_outline,
                            color: Color(0xFF1565C0),
                            size: 18),
                        childrenPadding:
                        const EdgeInsets.fromLTRB(
                            16, 0, 16, 12),
                        children: instructions
                            .map((instr) => Padding(
                          padding:
                          const EdgeInsets.only(
                              bottom: 6),
                          child: Row(
                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                            children: [
                              const Icon(
                                  Icons.circle,
                                  size: 6,
                                  color: Color(
                                      0xFF1565C0)),
                              const SizedBox(
                                  width: 8),
                              Expanded(
                                child: Text(instr,
                                    style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: const Color(
                                            0xFF374151))),
                              ),
                            ],
                          ),
                        ))
                            .toList(),
                      ),
                    ),

                  // Download button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        16, 0, 16, 14),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _downloadAdmitCard(card),
                        icon: const Icon(
                            Icons.open_in_new_rounded,
                            size: 16,
                            color: Colors.white),
                        label: Text(
                          status == 'expired'
                              ? 'Open Official Website'
                              : 'Download Admit Card →',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: status ==
                              'expired'
                              ? const Color(0xFF6B7280)
                              : const Color(0xFF1565C0),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(
                                  10)),
                          padding:
                          const EdgeInsets.symmetric(
                              vertical: 12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Upcoming — notify me button
          if (status == 'upcoming') ...[
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF9FAFB),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(
                  16, 10, 16, 14),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _setReminder(card),
                  icon: const Icon(
                      Icons.notifications_outlined,
                      size: 16,
                      color: Colors.white),
                  label: Text(
                      'Notify Me When Released',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w500)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    const Color(0xFFF59E0B),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(
      IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon,
            size: 14, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: const Color(0xFF9CA3AF))),
              Text(value,
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A2E))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _countdownBox(
      String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border:
        Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
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
          case 0:
            Navigator.pushReplacementNamed(
                context, '/home'); break;
          case 1:
            Navigator.pushReplacementNamed(
                context, '/jobs'); break;
          case 2:
            Navigator.pushReplacementNamed(
                context, '/current-affairs'); break;
          case 3:
            Navigator.pushReplacementNamed(
                context, '/saved'); break;
          case 4:
            Navigator.pushReplacementNamed(
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
