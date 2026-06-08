import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../services/job_service.dart';

class JobTrackerScreen extends StatefulWidget {
  const JobTrackerScreen({super.key});

  @override
  State<JobTrackerScreen> createState() =>
      _JobTrackerScreenState();
}

class _JobTrackerScreenState extends State<JobTrackerScreen> {
  String _selectedStatus = 'All';
  bool _isLoading = true;
  List<Map<String, dynamic>> _trackedJobs = [];
  List<Map<String, dynamic>> _allJobs     = [];
  final JobService _jobService = JobService();

  final List<String> _statusFilters = [
    'All', 'Applied', 'Exam Scheduled',
    'Result Awaited', 'Selected', 'Not Selected',
  ];

  @override
  void initState() {
    super.initState();
    _loadTrackedJobs();
    _loadAllJobs();
  }

  // ── Load tracked jobs from Firebase ───────────────────
  Future<void> _loadTrackedJobs() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('trackedJobs')
          .orderBy('addedAt', descending: true)
          .get();

      setState(() {
        _trackedJobs = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading tracked jobs: $e');
      setState(() => _isLoading = false);
    }
  }

  // ── Add new tracked job ────────────────────────────────
  Future<void> _loadAllJobs() async {
    try {
      final jobs = await _jobService.getAllJobs();
      setState(() => _allJobs = jobs);
    } catch (e) {
      print('Error loading jobs: $e');
    }
  }

  Future<void> _addTrackedJob(
      Map<String, dynamic> jobData) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('trackedJobs')
          .add({
        'title':           jobData['title'] ?? '',
        'organization':    jobData['organization'] ?? '',
        'category':        jobData['category'] ?? '',
        'registrationNo':  jobData['registrationNo'] ?? '',
        'status':          jobData['status'] ?? 'Interested',
        'appliedDate':     jobData['appliedDate'] ?? '',
        'examDate':        'TBA',
        'notes':           jobData['notes'] ?? '',
        'stages':          _getDefaultStages(
            jobData['category'] ?? ''),
        'addedAt':         FieldValue.serverTimestamp(),
      });

      // Also add to user's appliedJobs array
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'appliedJobs': FieldValue.arrayUnion(
            [jobData['title'] ?? '']),
      }, SetOptions(merge: true));

      // FIX BUG 1: Also write to trackedJobs array on user doc
      // so profile stats read correctly
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'trackedJobs': FieldValue.arrayUnion(
            [jobData['title'] ?? '']),
      }, SetOptions(merge: true));

      _loadTrackedJobs();
    } catch (e) {
      print('Error adding tracked job: $e');
    }
  }

  // ── Update job status ──────────────────────────────────
  Future<void> _updateStatus(
      String docId, String newStatus) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('trackedJobs')
          .doc(docId)
          .update({'status': newStatus});

      _loadTrackedJobs();
    } catch (e) {
      print('Error updating status: $e');
    }
  }

  // ── Delete tracked job ─────────────────────────────────
  Future<void> _deleteTrackedJob(String docId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get the job title before deleting so we can remove from array
      final docSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('trackedJobs')
          .doc(docId)
          .get();
      final String jobTitle =
          docSnap.data()?['title'] as String? ?? '';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('trackedJobs')
          .doc(docId)
          .delete();

      // FIX BUG 1: Also remove from trackedJobs array on user doc
      if (jobTitle.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'trackedJobs': FieldValue.arrayRemove([jobTitle]),
        }, SetOptions(merge: true));
      }

      _loadTrackedJobs();
    } catch (e) {
      print('Error deleting tracked job: $e');
    }
  }

  // ── Default stages by category ─────────────────────────
  List<Map<String, dynamic>> _getDefaultStages(
      String category) {
    switch (category) {
      case 'Railway':
        return [
          {'name': 'Application', 'done': true, 'date': ''},
          {'name': 'CBT Stage 1', 'done': false, 'date': 'TBA'},
          {'name': 'CBT Stage 2', 'done': false, 'date': 'TBA'},
          {'name': 'Document Verification', 'done': false, 'date': 'TBA'},
        ];
      case 'Police':
        return [
          {'name': 'Application', 'done': true, 'date': ''},
          {'name': 'Written Test', 'done': false, 'date': 'TBA'},
          {'name': 'Physical Test', 'done': false, 'date': 'TBA'},
          {'name': 'Medical Test', 'done': false, 'date': 'TBA'},
          {'name': 'Document Verification', 'done': false, 'date': 'TBA'},
        ];
      case 'Banking':
        return [
          {'name': 'Application', 'done': true, 'date': ''},
          {'name': 'Prelims', 'done': false, 'date': 'TBA'},
          {'name': 'Mains', 'done': false, 'date': 'TBA'},
          {'name': 'Interview', 'done': false, 'date': 'TBA'},
          {'name': 'Document Verification', 'done': false, 'date': 'TBA'},
        ];
      case 'Army':
        return [
          {'name': 'Application', 'done': true, 'date': ''},
          {'name': 'Physical Test', 'done': false, 'date': 'TBA'},
          {'name': 'Written Test', 'done': false, 'date': 'TBA'},
          {'name': 'Medical Test', 'done': false, 'date': 'TBA'},
          {'name': 'Document Verification', 'done': false, 'date': 'TBA'},
        ];
      case 'UPSC':
        return [
          {'name': 'Application', 'done': true, 'date': ''},
          {'name': 'Prelims', 'done': false, 'date': 'TBA'},
          {'name': 'Mains', 'done': false, 'date': 'TBA'},
          {'name': 'Interview', 'done': false, 'date': 'TBA'},
          {'name': 'Document Verification', 'done': false, 'date': 'TBA'},
        ];
      default:
        return [
          {'name': 'Application', 'done': true, 'date': ''},
          {'name': 'Written Test', 'done': false, 'date': 'TBA'},
          {'name': 'Document Verification', 'done': false, 'date': 'TBA'},
        ];
    }
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
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ],
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

  Color _statusColor(String status) {
    if (status.contains('Selected')) return Colors.green;
    switch (status) {
      case 'Applied':         return Colors.purple;
      case 'Exam Scheduled':  return Colors.blue;
      case 'Result Awaited':  return Colors.orange;
      case 'Not Selected':    return Colors.red;
      default:                return Colors.grey;
    }
  }

  List<Map<String, dynamic>> get _filteredJobs {
    if (_selectedStatus == 'All') return _trackedJobs;
    if (_selectedStatus == 'Selected') {
      return _trackedJobs
          .where((j) => (j['status'] as String? ?? '')
          .contains('Selected'))
          .toList();
    }
    return _trackedJobs
        .where((j) => j['status'] == _selectedStatus)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _trackedJobs
        .where((j) => (j['status'] as String? ?? '')
        .contains('Selected'))
        .length;
    final active = _trackedJobs
        .where((j) =>
    !(j['status'] as String? ?? '')
        .contains('Selected') &&
        j['status'] != 'Not Selected')
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(selected, active),
          _buildStatusFilters(),
          Expanded(
            child: _isLoading
                ? const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF1565C0)))
                : _filteredJobs.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _loadTrackedJobs,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _filteredJobs.length,
                itemBuilder: (context, index) =>
                    _buildTrackerCard(
                        _filteredJobs[index]),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddJobDialog(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded,
            color: Colors.white),
        label: Text('Track Job',
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold)),
      ),
      floatingActionButtonLocation:
      FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader(int selected, int active) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20, right: 20, bottom: 24,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pushReplacementNamed(
                    context, '/home'),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Job Tracker',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  Text('Track your complete exam journey',
                      style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 13)),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: _loadTrackedJobs,
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
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildHeaderStat(
                  '${_trackedJobs.length}', 'Total\nTracked'),
              const SizedBox(width: 20),
              _buildHeaderStat('$active', 'Active'),
              const SizedBox(width: 20),
              _buildHeaderStat('$selected', 'Selected'),
              const SizedBox(width: 20),
              _buildHeaderStat(
                _trackedJobs.isEmpty
                    ? '0%'
                    : '${(selected / _trackedJobs.length * 100).toStringAsFixed(0)}%',
                'Success\nRate',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: GoogleFonts.poppins(
                color: Colors.white, fontSize: 20,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: GoogleFonts.poppins(
                color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _buildStatusFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: _statusFilters.map((filter) {
            final isSelected = _selectedStatus == filter;
            return GestureDetector(
              onTap: () =>
                  setState(() => _selectedStatus = filter),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
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
    );
  }

  Widget _buildTrackerCard(Map<String, dynamic> job) {
    final String docId    = job['id'] as String? ?? '';
    final String title    = job['title'] as String? ?? '';
    final String org      = job['organization'] as String? ?? '';
    final String category = job['category'] as String? ?? '';
    final String status   = job['status'] as String? ?? '';
    final String regNo    = job['registrationNo'] as String? ?? '';
    final String notes    = job['notes'] as String? ?? '';
    final List<dynamic> stages =
        job['stages'] as List<dynamic>? ?? [];
    final Color color     = _categoryColor(category);
    final IconData icon   = _categoryIcon(category);
    final Color sColor    = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // ── Card Header ──────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1A2E))),
                      Text(org,
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: sColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: sColor.withOpacity(0.3)),
                  ),
                  child: Text(status,
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: sColor,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Registration number
                if (regNo.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius:
                      BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.confirmation_number_outlined,
                            size: 16,
                            color: Colors.grey.shade500),
                        const SizedBox(width: 8),
                        Text('Reg No: $regNo',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade600)),
                      ],
                    ),
                  ),

                if (regNo.isNotEmpty)
                  const SizedBox(height: 12),

                // Progress stages
                if (stages.isNotEmpty) ...[
                  Text('Progress',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF374151))),
                  const SizedBox(height: 10),
                  ...stages.asMap().entries.map((entry) {
                    final i     = entry.key;
                    final stage = entry.value as Map;
                    final bool done =
                        stage['done'] as bool? ?? false;
                    final String date =
                        stage['date'] as String? ?? 'TBA';
                    return Padding(
                      padding: const EdgeInsets.only(
                          bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: done
                                  ? color
                                  : Colors.grey.shade200,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              done
                                  ? Icons.check_rounded
                                  : Icons.radio_button_unchecked,
                              color: done
                                  ? Colors.white
                                  : Colors.grey,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              stage['name'] as String? ?? '',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: done
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: done
                                    ? const Color(0xFF1A1A2E)
                                    : Colors.grey,
                              ),
                            ),
                          ),
                          Text(date,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade400)),
                        ],
                      ),
                    );
                  }),
                ],

                // Notes
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.08),
                      borderRadius:
                      BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.amber
                              .withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.sticky_note_2_outlined,
                            size: 16,
                            color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(notes,
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.amber
                                      .shade800)),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            _showStatusDialog(docId, status),
                        child: Container(
                          height: 38,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius:
                            BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                color.withOpacity(0.3)),
                          ),
                          child: Center(
                            child: Text('Update Status',
                                style: TextStyle(
                                    color: color,
                                    fontSize: 12,
                                    fontWeight:
                                    FontWeight.w600)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () =>
                          _showDeleteDialog(docId, title),
                      child: Container(
                        height: 38,
                        width: 38,
                        decoration: BoxDecoration(
                          color: Colors.red
                              .withOpacity(0.1),
                          borderRadius:
                          BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.red
                                  .withOpacity(0.3)),
                        ),
                        child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.red, size: 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Add Job Dialog ─────────────────────────────────────
  void _showAddJobDialog() {
    String searchQuery       = '';
    Map<String, dynamic>? selectedJob;
    String selectedStatus    = 'Interested';
    final regNoCtrl          = TextEditingController();
    final notesCtrl          = TextEditingController();

    final statuses = [
      'Interested',
      'Planning to Apply',
      'Applied',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSheet) {
          // Filter jobs by search
          final filtered = searchQuery.isEmpty
              ? _allJobs
              : _allJobs.where((j) {
                  final title = (j['title'] as String? ?? '')
                      .toLowerCase();
                  final org = (j['organization'] as String? ?? '')
                      .toLowerCase();
                  return title.contains(
                          searchQuery.toLowerCase()) ||
                      org.contains(searchQuery.toLowerCase());
                }).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(24)),
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text('Track a Job',
                                style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(
                                        0xFF1A1A2E))),
                            Text(
                              'Select a job to track your progress',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color(
                                      0xFF6B7280)),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx2),
                        child: const Icon(Icons.close,
                            color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Step 1 — Job picker OR Step 2 — Details
                Expanded(
                  child: selectedJob == null
                      ? _buildJobPicker(
                          filtered, searchQuery,
                          (q) => setSheet(() => searchQuery = q),
                          (job) => setSheet(
                              () => selectedJob = job))
                      : SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            20, 16, 20,
                            MediaQuery.of(ctx2)
                                    .viewInsets
                                    .bottom +
                                20,
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              // Selected job card
                              Container(
                                padding:
                                    const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.primary
                                      .withOpacity(0.06),
                                  borderRadius:
                                      BorderRadius.circular(
                                          12),
                                  border: Border.all(
                                      color: AppColors.primary
                                          .withOpacity(0.2)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment
                                                .start,
                                        children: [
                                          Text(
                                            selectedJob![
                                                    'title'] as String? ??
                                                '',
                                            style: GoogleFonts
                                                .poppins(
                                                    fontSize:
                                                        14,
                                                    fontWeight:
                                                        FontWeight
                                                            .w600,
                                                    color: const Color(
                                                        0xFF1A1A2E)),
                                          ),
                                          Text(
                                            selectedJob![
                                                    'organization'] as String? ??
                                                '',
                                            style: GoogleFonts
                                                .poppins(
                                                    fontSize:
                                                        12,
                                                    color: const Color(
                                                        0xFF6B7280)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => setSheet(
                                          () =>
                                              selectedJob =
                                                  null),
                                      child: Container(
                                        padding:
                                            const EdgeInsets
                                                .symmetric(
                                                horizontal: 10,
                                                vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors
                                              .grey.shade100,
                                          borderRadius:
                                              BorderRadius
                                                  .circular(
                                                      8),
                                        ),
                                        child: Text('Change',
                                            style: GoogleFonts
                                                .poppins(
                                                    fontSize:
                                                        12,
                                                    color: AppColors
                                                        .primary)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Status selector
                              Text('Current Status',
                                  style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight:
                                          FontWeight.w600,
                                      color: const Color(
                                          0xFF374151))),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children:
                                    statuses.map((s) {
                                  final sel =
                                      selectedStatus == s;
                                  return GestureDetector(
                                    onTap: () => setSheet(
                                        () =>
                                            selectedStatus =
                                                s),
                                    child: Container(
                                      padding: const EdgeInsets
                                          .symmetric(
                                          horizontal: 16,
                                          vertical: 10),
                                      decoration: BoxDecoration(
                                        color: sel
                                            ? AppColors.primary
                                            : Colors
                                                .grey.shade50,
                                        borderRadius:
                                            BorderRadius
                                                .circular(20),
                                        border: Border.all(
                                          color: sel
                                              ? AppColors
                                                  .primary
                                              : Colors.grey
                                                  .shade300,
                                        ),
                                      ),
                                      child: Text(s,
                                          style: GoogleFonts
                                              .poppins(
                                                  fontSize:
                                                      13,
                                                  fontWeight:
                                                      FontWeight
                                                          .w500,
                                                  color: sel
                                                      ? Colors
                                                          .white
                                                      : const Color(
                                                          0xFF374151))),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 20),

                              // Registration number (only if Applied)
                              if (selectedStatus ==
                                  'Applied') ...[
                                Text('Registration Number',
                                    style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight:
                                            FontWeight.w600,
                                        color: const Color(
                                            0xFF374151))),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: regNoCtrl,
                                  decoration: InputDecoration(
                                    hintText:
                                        'Enter registration number',
                                    hintStyle:
                                        GoogleFonts.poppins(
                                            fontSize: 13,
                                            color: const Color(
                                                0xFF9CA3AF)),
                                    prefixIcon: const Icon(
                                        Icons
                                            .confirmation_number_outlined,
                                        color: Color(
                                            0xFF1565C0),
                                        size: 20),
                                    filled: true,
                                    fillColor:
                                        Colors.grey.shade50,
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius
                                                .circular(12),
                                        borderSide: BorderSide(
                                            color: Colors
                                                .grey.shade200)),
                                    enabledBorder:
                                        OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius
                                                    .circular(
                                                        12),
                                            borderSide: BorderSide(
                                                color: Colors
                                                    .grey
                                                    .shade200)),
                                    focusedBorder:
                                        OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius
                                                    .circular(
                                                        12),
                                            borderSide:
                                                const BorderSide(
                                                    color: Color(
                                                        0xFF1565C0),
                                                    width: 2)),
                                  ),
                                  style: GoogleFonts.poppins(
                                      fontSize: 14),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Notes
                              Text('Notes (Optional)',
                                  style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight:
                                          FontWeight.w600,
                                      color: const Color(
                                          0xFF374151))),
                              const SizedBox(height: 8),
                              TextField(
                                controller: notesCtrl,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  hintText:
                                      'Any notes about this job...',
                                  hintStyle:
                                      GoogleFonts.poppins(
                                          fontSize: 13,
                                          color: const Color(
                                              0xFF9CA3AF)),
                                  filled: true,
                                  fillColor:
                                      Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius
                                              .circular(12),
                                      borderSide: BorderSide(
                                          color: Colors
                                              .grey.shade200)),
                                  enabledBorder:
                                      OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius
                                                  .circular(
                                                      12),
                                          borderSide: BorderSide(
                                              color: Colors
                                                  .grey
                                                  .shade200)),
                                ),
                                style: GoogleFonts.poppins(
                                    fontSize: 14),
                              ),
                              const SizedBox(height: 28),

                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(ctx2);
                                    _addTrackedJob({
                                      'title': selectedJob![
                                              'title'] ??
                                          '',
                                      'organization':
                                          selectedJob![
                                                  'organization'] ??
                                              '',
                                      'category':
                                          selectedJob![
                                                  'category'] ??
                                              '',
                                      'status':
                                          selectedStatus,
                                      'registrationNo':
                                          regNoCtrl.text
                                              .trim(),
                                      'notes': notesCtrl.text
                                          .trim(),
                                      'appliedDate':
                                          '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                                      'jobId':
                                          selectedJob!['id'] ??
                                              '',
                                      'lastDate':
                                          selectedJob![
                                                  'lastDate'] ??
                                              'TBA',
                                      'examDate':
                                          selectedJob![
                                                  'examDate'] ??
                                              'TBA',
                                      'vacancies':
                                          selectedJob![
                                              'vacancies'],
                                    });
                                    _showToast(context,
                                        'Added to tracker');
                                  },
                                  style:
                                      ElevatedButton.styleFrom(
                                    backgroundColor:
                                        AppColors.primary,
                                    padding:
                                        const EdgeInsets
                                            .symmetric(
                                            vertical: 16),
                                    shape:
                                        RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius
                                                    .circular(
                                                        14)),
                                  ),
                                  child: Text('Add to Tracker',
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
          );
        },
      ),
    );
  }

  // ── Job picker list ────────────────────────────────────
  Widget _buildJobPicker(
    List<Map<String, dynamic>> jobs,
    String searchQuery,
    Function(String) onSearch,
    Function(Map<String, dynamic>) onSelect,
  ) {
    return Column(
      children: [
        // Search box
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            onChanged: onSearch,
            decoration: InputDecoration(
              hintText: 'Search jobs...',
              hintStyle: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF9CA3AF)),
              prefixIcon: const Icon(Icons.search,
                  color: Color(0xFF9CA3AF)),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
            style: GoogleFonts.poppins(fontSize: 14),
          ),
        ),
        // Job list
        Expanded(
          child: jobs.isEmpty
              ? Center(
                  child: Text('No jobs found',
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: const Color(0xFF6B7280))),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  itemCount: jobs.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final job = jobs[i];
                    final String title =
                        job['title'] as String? ?? '';
                    final String org =
                        job['organization'] as String? ?? '';
                    final String cat =
                        job['category'] as String? ?? '';
                    final dynamic vac = job['vacancies'];
                    return ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 4),
                      leading: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary
                              .withOpacity(0.1),
                          borderRadius:
                              BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.work_outline,
                            color: AppColors.primary,
                            size: 20),
                      ),
                      title: Text(title,
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color:
                                  const Color(0xFF1A1A2E))),
                      subtitle: Text(
                        '$org • $cat • ${vac ?? "TBA"} posts',
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            color:
                                const Color(0xFF6B7280)),
                      ),
                      trailing: const Icon(
                          Icons.chevron_right,
                          color: Color(0xFF9CA3AF)),
                      onTap: () => onSelect(job),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _dialogTextField(TextEditingController controller,
      String hint, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: Icon(icon,
            color: AppColors.primary, size: 20),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
            BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
            BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: AppColors.primary, width: 2)),
      ),
      style: GoogleFonts.poppins(fontSize: 14),
    );
  }

  // ── Update Status Dialog ───────────────────────────────
  void _showStatusDialog(String docId, String current) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Update Status',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _statusFilters
              .where((s) => s != 'All')
              .map((status) => ListTile(
            title: Text(status,
                style: GoogleFonts.poppins(
                    fontSize: 14)),
            leading: Icon(Icons.circle,
                color: _statusColor(status),
                size: 14),
            trailing: current == status
                ? Icon(Icons.check,
                color: AppColors.primary)
                : null,
            onTap: () {
              Navigator.pop(ctx);
              _updateStatus(docId, status);
            },
          ))
              .toList(),
        ),
      ),
    );
  }

  // ── Delete Confirmation Dialog ─────────────────────────
  void _showDeleteDialog(String docId, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Remove from Tracker',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold)),
        content: Text(
            'Remove "$title" from your job tracker?',
            style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.poppins(
                    color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteTrackedJob(docId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Remove',
                style: GoogleFonts.poppins(
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.track_changes_outlined,
              size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No jobs tracked yet!',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF374151))),
          const SizedBox(height: 8),
          Text(
              'Tap + Track Job to start\ntracking your applications!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF9CA3AF))),
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