import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';

class SavedJobsScreen extends StatefulWidget {
  const SavedJobsScreen({super.key});

  @override
  State<SavedJobsScreen> createState() => _SavedJobsScreenState();
}

class _SavedJobsScreenState extends State<SavedJobsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'All';
  bool _isLoading = true;

  List<Map<String, dynamic>> _savedJobs   = [];
  List<Map<String, dynamic>> _appliedJobs = [];

  final List<String> _filters = [
    'All', 'Railway', 'Police', 'Banking', 'SSC', 'Army',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSavedJobs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Load saved jobs from Firebase ─────────────────────
  Future<void> _loadSavedJobs() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Get user's saved job IDs
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        setState(() => _isLoading = false);
        return;
      }

      final data = userDoc.data()!;
      final savedIds =
      List<String>.from(data['savedJobs'] ?? []);
      final appliedIds =
      List<String>.from(data['appliedJobs'] ?? []);

      // Fetch saved job details
      List<Map<String, dynamic>> savedJobs = [];
      for (final id in savedIds) {
        try {
          final jobDoc = await FirebaseFirestore.instance
              .collection('jobs')
              .doc(id)
              .get();
          if (jobDoc.exists) {
            final jobData =
            jobDoc.data() as Map<String, dynamic>;
            jobData['id'] = jobDoc.id;
            savedJobs.add(jobData);
          }
        } catch (e) {
        }
      }

      // Fetch applied job details
      List<Map<String, dynamic>> appliedJobs = [];
      for (final id in appliedIds) {
        try {
          final jobDoc = await FirebaseFirestore.instance
              .collection('jobs')
              .doc(id)
              .get();
          if (jobDoc.exists) {
            final jobData =
            jobDoc.data() as Map<String, dynamic>;
            jobData['id'] = jobDoc.id;
            appliedJobs.add(jobData);
          }
        } catch (e) {
        }
      }

      setState(() {
        _savedJobs   = savedJobs;
        _appliedJobs = appliedJobs;
        _isLoading   = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // ── Remove saved job ───────────────────────────────────
  Future<void> _removeSavedJob(String jobId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'savedJobs': FieldValue.arrayRemove([jobId]),
      }, SetOptions(merge: true));

      setState(() {
        _savedJobs.removeWhere((j) => j['id'] == jobId);
      });

      _showToast('Removed from saved', success: false);
    } catch (e) {
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

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'Railway': return AppColors.railway;
      case 'Police':  return AppColors.police;
      case 'Banking': return AppColors.banking;
      case 'SSC':     return AppColors.ssc;
      case 'Army':    return AppColors.army;
      case 'Teaching':return const Color(0xFF0277BD);
      case 'Health':  return const Color(0xFFC62828);
      case 'UPSC':    return const Color(0xFF880E4F);
      default:        return AppColors.primary;
    }
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'Railway': return Icons.train_rounded;
      case 'Police':  return Icons.local_police_rounded;
      case 'Banking': return Icons.account_balance_rounded;
      case 'SSC':     return Icons.assignment_rounded;
      case 'Army':    return Icons.military_tech_rounded;
      case 'Teaching':return Icons.school_rounded;
      case 'Health':  return Icons.local_hospital_rounded;
      case 'UPSC':    return Icons.gavel_rounded;
      default:        return Icons.work_rounded;
    }
  }

  int _calculateDaysLeft(dynamic lastDate) {
    try {
      if (lastDate == null) return 0;
      if (lastDate.toString() == 'TBA') return 999;
      final parts = lastDate.toString().split('-');
      if (parts.length != 3) return 0;
      final date = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      return date.difference(DateTime.now()).inDays;
    } catch (e) {
      return 0;
    }
  }

  List<Map<String, dynamic>> get _filteredJobs {
    if (_selectedFilter == 'All') return _savedJobs;
    return _savedJobs
        .where((job) => job['category'] == _selectedFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey,
              labelStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, fontSize: 14),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment:
                    MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bookmark_rounded,
                          size: 18),
                      const SizedBox(width: 6),
                      Text('Saved (${_savedJobs.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment:
                    MainAxisAlignment.center,
                    children: [
                      const Icon(
                          Icons.track_changes_rounded,
                          size: 18),
                      const SizedBox(width: 6),
                      Text(
                          'Applied (${_appliedJobs.length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF1565C0)))
                : TabBarView(
              controller: _tabController,
              children: [
                _buildSavedTab(),
                _buildAppliedTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20, right: 20, bottom: 20,
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
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('My Jobs',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  Text('Saved and applied jobs',
                      style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 13)),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: _loadSavedJobs,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius:
                    BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.refresh_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _headerStat('${_savedJobs.length}',
                  'Saved\nJobs'),
              const SizedBox(width: 24),
              _headerStat('${_appliedJobs.length}',
                  'Applied\nJobs'),
              const SizedBox(width: 24),
              _headerStat('0', 'Selected\nJobs'),
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
                color: Colors.white, fontSize: 22,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: GoogleFonts.poppins(
                color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _buildSavedTab() {
    return Column(
      children: [
        // Filter chips
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding:
            const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _filters.map((filter) {
                final isSelected =
                    _selectedFilter == filter;
                return GestureDetector(
                  onTap: () => setState(
                          () => _selectedFilter = filter),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.grey.shade100,
                      borderRadius:
                      BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Text(filter,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        Expanded(
          child: _filteredJobs.isEmpty
              ? _buildEmptyState(
              'No saved jobs yet!',
              'Browse jobs and tap Save Job to add them here',
              Icons.bookmark_border_rounded)
              : RefreshIndicator(
            onRefresh: _loadSavedJobs,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredJobs.length,
              itemBuilder: (context, index) =>
                  _buildSavedJobCard(
                      _filteredJobs[index]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSavedJobCard(Map<String, dynamic> job) {
    final String category =
        job['category'] as String? ?? 'SSC';
    final Color color     = _categoryColor(category);
    final IconData icon   = _categoryIcon(category);
    final String title    = job['title'] as String? ?? '';
    final String org      = job['organization'] as String? ?? '';
    final int vacancies   = (job['vacancies'] ?? 0) as int;
    final String salary   = job['salary'] as String? ?? '';
    final String lastDate = job['lastDate'] as String? ?? '';
    final String jobId    = job['id'] as String? ?? '';
    return Dismissible(
      key: Key(jobId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded,
            color: Colors.white, size: 28),
      ),
      onDismissed: (_) => _removeSavedJob(jobId),
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(
          context, '/job-detail',
          arguments: Map<String, dynamic>.from(job),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius:
                      BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color,
                        size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color:
                                const Color(0xFF1A1A2E))),
                        Text(org,
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _infoChip(Icons.people_outline,
                      '$vacancies Posts'),
                  const SizedBox(width: 16),
                  _infoChip(Icons.currency_rupee_outlined,
                      salary),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                      lastDate == 'TBA'
                          ? 'Last Date: Not Announced'
                          : 'Last Date: $lastDate',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade500)),
                  Text('← Swipe to remove',
                      style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey.shade400)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13,
            color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 3),
        Text(text,
            style: GoogleFonts.poppins(
                fontSize: 11,
                color: const Color(0xFF374151))),
      ],
    );
  }

  Widget _buildAppliedTab() {
    if (_appliedJobs.isEmpty) {
      return _buildEmptyState(
          'No applied jobs yet!',
          'Jobs you apply for will appear here',
          Icons.track_changes_rounded);
    }

    return RefreshIndicator(
      onRefresh: _loadSavedJobs,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _appliedJobs.length,
        itemBuilder: (context, index) {
          final job = _appliedJobs[index];
          final String category =
              job['category'] as String? ?? 'SSC';
          final Color color = _categoryColor(category);
          final IconData icon = _categoryIcon(category);
          final String title =
              job['title'] as String? ?? '';
          final String org =
              job['organization'] as String? ?? '';

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius:
                    BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color,
                      size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color:
                              const Color(0xFF1A1A2E))),
                      Text(org,
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey.shade500)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.blue
                              .withOpacity(0.1),
                          borderRadius:
                          BorderRadius.circular(6),
                        ),
                        child: Text('Applied',
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.blue,
                                fontWeight:
                                FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(
      String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80,
              color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF374151))),
          const SizedBox(height: 8),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF9CA3AF))),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () =>
                Navigator.pushReplacementNamed(
                    context, '/jobs'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(12)),
            ),
            child: Text('Browse Jobs',
                style: GoogleFonts.poppins(
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: 3,
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
          case 3: break;
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