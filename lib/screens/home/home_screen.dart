import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/job_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../study/study_material_screen.dart';
import '../current_affairs/current_affairs_screen.dart';
import '../../l10n/language_provider.dart';
import '../../l10n/app_strings.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  final JobService _jobService = JobService();
  List<Map<String, dynamic>> _latestJobs = [];
  bool _isLoading = true;
  bool _hasInternet = true;
  String _userName = 'User';

  // Exam list for the Mock Test quick-pick dialog — kept in sync with
  // study_material_screen.dart's _exams list.
  final List<String> _mockTestExams = [
    'SSC CGL','SSC CHSL','RRB NTPC','Army Agniveer','Punjab Police',
    'IBPS PO','UPSC CSE','Delhi Police','Haryana Police','NDA',
  ];

  final List<Map<String, dynamic>> _upcomingExams = [
    {
      'name': 'SSC CGL Tier 1',
      'date': '01 Sep 2026',
      'color': Color(0xFFE65100),
      'icon': Icons.description,
    },
    {
      'name': 'RRB NTPC CBT 1',
      'date': '15 Aug 2026',
      'color': Color(0xFF1565C0),
      'icon': Icons.train,
    },
    {
      'name': 'IBPS PO Prelims',
      'date': '05 Oct 2026',
      'color': Color(0xFF6A1B9A),
      'icon': Icons.account_balance,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadLatestJobs();
    _loadUserName();
  }

  // ── Load user name from Firestore ──────────────────────
  Future<void> _loadUserName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          final name = doc.data()?['fullName'];
          if (name != null && name.toString().isNotEmpty) {
            setState(() => _userName = name.toString());
            return;
          }
        }
        // Fallback to display name
        if (user.displayName != null &&
            user.displayName!.isNotEmpty) {
          setState(() => _userName = user.displayName!);
        } else if (user.email != null) {
          setState(() =>
          _userName = user.email!.split('@')[0]);
        }
      }
    } catch (e) {}
  }

  Future<void> _checkInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      setState(() => _hasInternet = result.isNotEmpty && result[0].rawAddress.isNotEmpty);
    } catch (_) {
      setState(() => _hasInternet = false);
    }
  }

  Future<void> _loadLatestJobs() async {
    await _checkInternet();
    if (!_hasInternet) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final jobs = await _jobService.getNewJobs();
      setState(() {
        _latestJobs = jobs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
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

  // ── Mock Test quick-pick: shows exam selector, then jumps straight
  // into Study Material's Mock Test tab for that exam ──────────────
  void _showMockTestExamPicker(String lang) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.quiz_outlined,
                        color: Color(0xFF1565C0), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppStrings.get('choose_exam_title', lang),
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A1A2E))),
                      Text(AppStrings.get('choose_exam_sub', lang),
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.grey.shade500)),
                    ],
                  )),
                ]),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  itemCount: _mockTestExams.length,
                  itemBuilder: (_, i) {
                    final exam = _mockTestExams[i];
                    return ListTile(
                      leading: Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1565C0).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.menu_book_outlined,
                            color: Color(0xFF1565C0), size: 18),
                      ),
                      title: Text(exam, style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A1A2E))),
                      trailing: Icon(Icons.chevron_right,
                          color: Colors.grey.shade400),
                      onTap: () {
                        Navigator.pop(ctx); // close the sheet
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => StudyMaterialScreen(
                            initialExam: exam,
                            initialTabIndex: 2, // Mock Test tab
                          ),
                        ));
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().languageCode;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            // ── No Internet Banner ─────────────────────────
            if (!_hasInternet)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                color: const Color(0xFFEF4444),
                child: Row(children: [
                  const Icon(Icons.wifi_off,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    AppStrings.get('no_internet_banner', lang),
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontSize: 12),
                  )),
                  GestureDetector(
                    onTap: () {
                      setState(() => _isLoading = true);
                      _loadLatestJobs();
                      _loadUserName();
                    },
                    child: Text(AppStrings.get('retry', lang),
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildHeader(lang),
                    _buildSearchBar(lang),
                    _buildCategories(lang),
                    _buildSectionTitle(AppStrings.get('latest_jobs', lang), AppStrings.get('see_all', lang)),
                    _buildJobCards(lang),
                    _buildSectionTitle(AppStrings.get('upcoming_exams', lang), AppStrings.get('see_all', lang)),
                    _buildExamCards(lang),
                    _buildSectionTitle(AppStrings.get('quick_tools_title', lang), ''),
                    _buildQuickTools(lang),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(lang),
    );
  }

  Widget _buildHeader(String lang) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${AppStrings.get('hello_greeting', lang)} 👋',
                      style: GoogleFonts.poppins(
                          color: Colors.white70, fontSize: 14)),
                  Text(_userName,
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 20,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(
                        context, '/notifications'),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                          Icons.notifications_outlined,
                          color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () =>
                        Navigator.pushNamed(context, '/profile'),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor:
                      Colors.white.withOpacity(0.2),
                      child: const Icon(Icons.person,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _headerStat('15+', AppStrings.get('states_stat', lang)),
              const SizedBox(width: 24),
              _headerStat(AppStrings.get('daily_stat', lang), AppStrings.get('updates_stat', lang)),
              const SizedBox(width: 24),
              _headerMotivation(lang),
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
                color: Colors.white, fontSize: 18,
                fontWeight: FontWeight.w700)),
        Text(label,
            style: GoogleFonts.poppins(
                color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _headerMotivation(String lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppStrings.get('dream_big', lang),
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        Text(AppStrings.get('work_hard', lang),
            style: GoogleFonts.poppins(
                color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildSearchBar(String lang) {
    return Container(
      color: const Color(0xFF1565C0),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/jobs'),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.search,
                  color: Color(0xFF9CA3AF)),
              const SizedBox(width: 10),
              Text(AppStrings.get('search_placeholder', lang),
                  style: GoogleFonts.poppins(
                      color: const Color(0xFF9CA3AF),
                      fontSize: 14)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(AppStrings.get('filter', lang),
                    style: GoogleFonts.poppins(
                        color: const Color(0xFF1565C0),
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategories(String lang) {
    final categories = [
      {'name': 'Railway', 'key': 'cat_railway', 'icon': Icons.train, 'color': Color(0xFF1565C0)},
      {'name': 'Police', 'key': 'cat_police', 'icon': Icons.local_police, 'color': Color(0xFF1B5E20)},
      {'name': 'Banking', 'key': 'cat_banking', 'icon': Icons.account_balance, 'color': Color(0xFF6A1B9A)},
      {'name': 'SSC', 'key': 'cat_ssc', 'icon': Icons.description, 'color': Color(0xFFE65100)},
      {'name': 'Army', 'key': 'cat_army', 'icon': Icons.military_tech, 'color': Color(0xFF33691E)},
      {'name': 'Teaching', 'key': 'cat_teaching', 'icon': Icons.school, 'color': Color(0xFF0277BD)},
      {'name': 'Health', 'key': 'cat_health', 'icon': Icons.local_hospital, 'color': Color(0xFFC62828)},
      {'name': 'More', 'key': 'cat_more', 'icon': Icons.grid_view, 'color': Color(0xFF455A64)},
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SizedBox(
        height: 80,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: categories.length,
          itemBuilder: (context, i) {
            final cat = categories[i];
            return GestureDetector(
              onTap: () => Navigator.pushNamed(
                context, '/jobs',
                // IMPORTANT: navigation argument stays the original
                // English 'name' value always — this is the actual
                // filter key the Jobs screen matches against, and
                // must never change with language, or filtering breaks.
                arguments: cat['name'] == 'More'
                    ? ''
                    : cat['name'] as String,
              ),
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                child: Column(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: (cat['color'] as Color)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(cat['icon'] as IconData,
                          color: cat['color'] as Color,
                          size: 22),
                    ),
                    const SizedBox(height: 6),
                    // Display text DOES translate — only the
                    // navigation argument above stays English.
                    Text(AppStrings.get(cat['key'] as String, lang),
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: const Color(0xFF374151),
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, String action) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A2E))),
          if (action.isNotEmpty)
            GestureDetector(
              onTap: () =>
                  Navigator.pushNamed(context, '/jobs'),
              child: Text(action,
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF1565C0),
                      fontWeight: FontWeight.w500)),
            ),
        ],
      ),
    );
  }

  Widget _buildJobCards(String lang) {
    if (_isLoading) {
      return const SizedBox(
        height: 175,
        child: Center(
          child: CircularProgressIndicator(
              color: Color(0xFF1565C0)),
        ),
      );
    }

    if (_latestJobs.isEmpty) {
      return SizedBox(
        height: 175,
        child: Center(
          child: Text(AppStrings.get('no_jobs_available', lang),
              style: GoogleFonts.poppins(
                  color: const Color(0xFF6B7280))),
        ),
      );
    }

    return SizedBox(
      height: 175,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _latestJobs.length,
        itemBuilder: (context, i) {
          final job = _latestJobs[i];
          // NOTE: title/org come from Firestore job data, not app UI —
          // these stay as-is for now (job content translation is a
          // separate, larger task, scoped out of this UI-strings pass).
          final String title    = job['title']?.toString() ?? '';
          final String org      = job['organization']?.toString() ?? '';
          final String category = job['category']?.toString() ?? 'SSC';
          final int vacancies   = int.tryParse(job['vacancies'].toString()) ?? 0;
          final bool isNew      = job['isNew'] == true;
          final Color color     = _categoryColor(category);

          return GestureDetector(
            onTap: () => Navigator.pushNamed(
              context, '/job-detail',
              arguments: Map<String, dynamic>.from(job),
            ),
            child: Container(
              width: 220,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius:
                          BorderRadius.circular(10),
                        ),
                        child: Icon(_categoryIcon(category),
                            color: color, size: 18),
                      ),
                      const Spacer(),
                      if (isNew)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius:
                            BorderRadius.circular(20),
                          ),
                          child: Text(AppStrings.get('new_badge', lang),
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A1A2E))),
                  const SizedBox(height: 2),
                  Text(org,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF6B7280))),
                  const Spacer(),
                  Text('$vacancies ${AppStrings.get('posts_label', lang)}',
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF374151),
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExamCards(String lang) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: _upcomingExams.map((exam) {
          final Color color = exam['color'] as Color;
          return GestureDetector(
            onTap: () =>
                Navigator.pushNamed(context, '/calendar'),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: color.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(exam['icon'] as IconData,
                        color: color, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(exam['name'] as String,
                            style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color:
                                const Color(0xFF1A1A2E))),
                        Text('${AppStrings.get('exam_date_label', lang)} ${exam['date']}',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color:
                                const Color(0xFF6B7280))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuickTools(String lang) {
    final tools = [
      {
        'icon': Icons.quiz_outlined,
        'title': AppStrings.get('mock_test', lang),
        'subtitle': AppStrings.get('mock_test_sub', lang),
        'color': Color(0xFF1565C0),
        'isMockTest': true,
      },
      {
        'icon': Icons.flash_on_outlined,
        'title': AppStrings.get('quick_quiz', lang),
        'subtitle': AppStrings.get('quick_quiz_sub', lang),
        'color': Color(0xFFF59E0B),
        'isQuickQuiz': true,
      },
      {
        'icon': Icons.psychology_alt_outlined,
        'title': AppStrings.get('memory_box', lang),
        'subtitle': AppStrings.get('memory_box_sub', lang),
        'color': Color(0xFFEF4444),
        'route': '/memory-box',
      },
      {
        'icon': Icons.menu_book_outlined,
        'title': AppStrings.get('study_material', lang),
        'subtitle': AppStrings.get('study_material_sub', lang),
        'color': Color(0xFF6A1B9A),
        'route': '/study-material',
      },
      {
        'icon': Icons.emoji_events_outlined,
        'title': AppStrings.get('results', lang),
        'subtitle': AppStrings.get('results_sub', lang),
        'color': Color(0xFF10B981),
        'route': '/results',
      },
      {
        'icon': Icons.track_changes_outlined,
        'title': AppStrings.get('job_tracker', lang),
        'subtitle': AppStrings.get('job_tracker_sub', lang),
        'color': Color(0xFFFF6B00),
        'route': '/tracker',
      },
      {
        'icon': Icons.article_outlined,
        'title': AppStrings.get('admit_cards', lang),
        'subtitle': AppStrings.get('admit_cards_sub', lang),
        'color': Color(0xFF1565C0),
        'route': '/admit-card',
      },
      {
        'icon': Icons.verified_user_outlined,
        'title': AppStrings.get('eligibility', lang),
        'subtitle': AppStrings.get('eligibility_sub', lang),
        'color': Color(0xFF10B981),
        'route': '/eligibility',
      },
      {
        'icon': Icons.cake_outlined,
        'title': AppStrings.get('age_calculator', lang),
        'subtitle': AppStrings.get('age_calculator_sub', lang),
        'color': Color(0xFF1565C0),
        'route': '/tools',
      },
      {
        'icon': Icons.calendar_month_outlined,
        'title': AppStrings.get('exam_calendar', lang),
        'subtitle': AppStrings.get('exam_calendar_sub', lang),
        'color': Color(0xFF880E4F),
        'route': '/calendar',
      },
      {
        'icon': Icons.newspaper_outlined,
        'title': AppStrings.get('current_affairs', lang),
        'subtitle': AppStrings.get('current_affairs_sub', lang),
        'color': Color(0xFF880E4F),
        'route': '/current-affairs',
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate:
        const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6,
        ),
        itemCount: tools.length,
        itemBuilder: (context, i) {
          final tool = tools[i];
          final Color color = tool['color'] as Color;
          final bool isMockTest = tool['isMockTest'] == true;
          final bool isQuickQuiz = tool['isQuickQuiz'] == true;

          return GestureDetector(
            onTap: () {
              if (isMockTest) {
                _showMockTestExamPicker(lang);
              } else if (isQuickQuiz) {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const CurrentAffairsScreen(
                    initialTabIndex: 1, // Daily Quiz tab
                  ),
                ));
              } else {
                Navigator.pushNamed(context, tool['route'] as String);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(tool['icon'] as IconData,
                        color: color, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        Text(tool['title'] as String,
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color:
                                const Color(0xFF1A1A2E))),
                        Text(tool['subtitle'] as String,
                            style: GoogleFonts.poppins(
                                fontSize: 10,
                                color:
                                const Color(0xFF6B7280))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomNav(String lang) {
    return BottomNavigationBar(
      currentIndex: 0,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF1565C0),
      unselectedItemColor: const Color(0xFF9CA3AF),
      selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11),
      onTap: (i) {
        switch (i) {
          case 0: break;
          case 1: Navigator.pushReplacementNamed(context, '/jobs'); break;
          case 2: Navigator.pushReplacementNamed(context, '/current-affairs'); break;
          case 3: Navigator.pushReplacementNamed(context, '/saved'); break;
          case 4: Navigator.pushReplacementNamed(context, '/profile'); break;
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
}