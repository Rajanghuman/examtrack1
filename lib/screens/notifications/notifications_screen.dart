import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _selectedFilter = 'All';
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];

  final List<String> _filters = [
    'All', 'Jobs', 'Exams', 'Deadlines',
  ];

  // ── Evergreen welcome notifications — no dates, always relevant ──
  static final List<Map<String, dynamic>> _seedNotifications = [
    {
      'title': 'Welcome to ExamTrack! 🎉',
      'body': 'Your ultimate guide to government jobs. We cover 34+ jobs across Railway, Police, Banking, SSC, Army and more. Let\'s get started!',
      'type': 'Jobs',
      'isRead': false,
      'isImportant': true,
      'createdAt': Timestamp.now(),
    },
    {
      'title': 'Complete Your Profile 👤',
      'body': 'Add your DOB, qualification and state to get personalised job recommendations and accurate eligibility checks. Go to Profile → Edit.',
      'type': 'Jobs',
      'isRead': false,
      'isImportant': true,
      'createdAt': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(minutes: 2))),
    },
    {
      'title': 'Browse 34+ Government Jobs 💼',
      'body': 'Explore jobs from SSC CGL, RRB NTPC, IBPS PO, Punjab Police, Army Agniveer, UPSC and many more — all in one place. Tap the Jobs tab to explore.',
      'type': 'Jobs',
      'isRead': false,
      'isImportant': false,
      'createdAt': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(minutes: 5))),
    },
    {
      'title': 'Check Your Eligibility ✅',
      'body': 'Not sure which jobs you qualify for? Use the Eligibility Checker — enter your age, qualification and category to instantly see all eligible jobs.',
      'type': 'Exams',
      'isRead': false,
      'isImportant': false,
      'createdAt': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(minutes: 10))),
    },
    {
      'title': 'Try the Daily Quiz 🧠',
      'body': 'Sharpen your knowledge with daily quiz questions on General Knowledge, Current Affairs, Reasoning and more. A new quiz is available every day — try it now!',
      'type': 'Exams',
      'isRead': true,
      'isImportant': false,
      'createdAt': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(minutes: 15))),
    },
    {
      'title': 'Take a Mock Test 📝',
      'body': 'Practice with full-length mock tests and get detailed topic-wise performance analysis. See exactly where you are strong and where to improve. Give it a try!',
      'type': 'Exams',
      'isRead': true,
      'isImportant': false,
      'createdAt': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(minutes: 20))),
    },
    {
      'title': 'Read Today\'s Current Affairs 📰',
      'body': 'Stay updated with daily current affairs — essential for every government exam. Check the News tab for the latest national and state-level updates.',
      'type': 'Exams',
      'isRead': true,
      'isImportant': false,
      'createdAt': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(minutes: 30))),
    },
    {
      'title': 'Know the Full Syllabus 📚',
      'body': 'Every job on ExamTrack has a complete, verified syllabus with topic-by-topic breakdown. Open any job → tap the Syllabus tab to start preparing smartly.',
      'type': 'Exams',
      'isRead': true,
      'isImportant': false,
      'createdAt': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(hours: 1))),
    },
    {
      'title': 'Save Jobs for Later 🔖',
      'body': 'Found an interesting job? Tap the bookmark icon to save it. Access all your saved jobs anytime from the Saved tab at the bottom.',
      'type': 'Jobs',
      'isRead': true,
      'isImportant': false,
      'createdAt': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(hours: 2))),
    },
    {
      'title': 'Smart Job Match Score 🎯',
      'body': 'Every job shows a personalised match score based on your profile — qualification, age, state and category. Higher score means a better fit for you!',
      'type': 'Jobs',
      'isRead': true,
      'isImportant': false,
      'createdAt': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(hours: 3))),
    },
    {
      'title': 'Never Miss a Deadline ⏰',
      'body': 'ExamTrack tracks application deadlines, exam dates, admit cards and results for all 34+ jobs. Enable notifications to always stay one step ahead.',
      'type': 'Deadlines',
      'isRead': true,
      'isImportant': false,
      'createdAt': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(hours: 4))),
    },
    {
      'title': 'Data Verified from Official Sources 🔐',
      'body': 'All job listings, syllabus and exam details are verified from official sources like ssc.gov.in, indianrailways.gov.in and ibps.in. You can trust ExamTrack.',
      'type': 'Jobs',
      'isRead': true,
      'isImportant': false,
      'createdAt': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(hours: 5))),
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) { setState(() => _isLoading = false); return; }

      final colRef = FirebaseFirestore.instance
          .collection('users').doc(user.uid).collection('notifications');

      final snapshot = await colRef.orderBy('createdAt', descending: true).get();

      if (snapshot.docs.isEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (final n in _seedNotifications) { batch.set(colRef.doc(), n); }
        await batch.commit();
        final seeded = await colRef.orderBy('createdAt', descending: true).get();
        _setNotifications(seeded);
      } else {
        _setNotifications(snapshot);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _setNotifications(QuerySnapshot snapshot) {
    setState(() {
      _notifications = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
      _isLoading = false;
    });
  }

  Future<void> _markRead(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users').doc(user.uid)
        .collection('notifications').doc(docId)
        .update({'isRead': true});
    setState(() {
      final idx = _notifications.indexWhere((n) => n['id'] == docId);
      if (idx != -1) _notifications[idx]['isRead'] = true;
    });
  }

  Future<void> _markAllRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final n in _notifications) {
      if (n['isRead'] == false) {
        final ref = FirebaseFirestore.instance
            .collection('users').doc(user.uid)
            .collection('notifications').doc(n['id'] as String);
        batch.update(ref, {'isRead': true});
      }
    }
    await batch.commit();
    setState(() { for (final n in _notifications) { n['isRead'] = true; } });
  }

  Future<void> _deleteNotification(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users').doc(user.uid)
        .collection('notifications').doc(docId).delete();
    setState(() { _notifications.removeWhere((n) => n['id'] == docId); });
  }

  List<Map<String, dynamic>> get _filteredNotifications {
    if (_selectedFilter == 'All') return _notifications;
    return _notifications.where((n) => n['type'] == _selectedFilter).toList();
  }

  int get _unreadCount => _notifications.where((n) => n['isRead'] == false).length;

  Color _typeColor(String type) {
    switch (type) {
      case 'Jobs':        return AppColors.primary;
      case 'Exams':       return const Color(0xFF7B1FA2);
      case 'Results':     return Colors.purple;
      case 'Admit Cards': return Colors.green;
      case 'Deadlines':   return Colors.red;
      default:            return Colors.grey;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'Jobs':        return Icons.work_rounded;
      case 'Exams':       return Icons.event_rounded;
      case 'Results':     return Icons.emoji_events_rounded;
      case 'Admit Cards': return Icons.card_membership_rounded;
      case 'Deadlines':   return Icons.alarm_rounded;
      default:            return Icons.notifications_rounded;
    }
  }

  String _formatTime(dynamic createdAt) {
    if (createdAt == null) return '';
    try {
      final date = (createdAt as Timestamp).toDate();
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1)  return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24)   return '${diff.inHours}h ago';
      if (diff.inDays == 1)    return 'Yesterday';
      if (diff.inDays < 7)     return '${diff.inDays} days ago';
      return '1 week ago';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [
        _buildHeader(),
        _buildFilterChips(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0)))
              : _filteredNotifications.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredNotifications.length,
                    itemBuilder: (context, index) =>
                        _buildNotificationCard(_filteredNotifications[index]),
                  ),
                ),
        ),
      ]),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    final jobCount      = _notifications.where((n) => n['type'] == 'Jobs').length;
    final deadlineCount = _notifications.where((n) => n['type'] == 'Deadlines').length;
    final importantCount = _notifications.where((n) => n['isImportant'] == true).length;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20, right: 20, bottom: 24,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            GestureDetector(
              onTap: () => Navigator.pushReplacementNamed(context, '/home'),
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Notifications', style: GoogleFonts.poppins(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              Text('$_unreadCount unread notifications', style: GoogleFonts.poppins(
                  color: Colors.white70, fontSize: 13)),
            ]),
          ]),
          if (_unreadCount > 0)
            GestureDetector(
              onTap: _markAllRead,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20)),
                child: Text('Mark all read', style: GoogleFonts.poppins(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _buildHeaderStat('$_unreadCount', 'Unread'),
          const SizedBox(width: 24),
          _buildHeaderStat('$jobCount', 'Job Alerts'),
          const SizedBox(width: 24),
          _buildHeaderStat('$deadlineCount', 'Deadlines'),
          const SizedBox(width: 24),
          _buildHeaderStat('$importantCount', 'Important'),
        ]),
      ]),
    );
  }

  Widget _buildHeaderStat(String value, String label) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: GoogleFonts.poppins(
          color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      Text(label, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
    ]);
  }

  Widget _buildFilterChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: _filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          final count = filter == 'All'
              ? _notifications.length
              : _notifications.where((n) => n['type'] == filter).length;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected
                    ? AppColors.primary : Colors.grey.shade200),
              ),
              child: Row(children: [
                Text(filter, style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                    fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.3) : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$count', style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey.shade600,
                      fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ]),
            ),
          );
        }).toList()),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final String docId    = notification['id'] as String? ?? '';
    final String type     = notification['type'] as String? ?? 'Jobs';
    final bool isUnread   = notification['isRead'] == false;
    final bool isImportant = notification['isImportant'] == true;
    final Color color     = _typeColor(type);
    final IconData icon   = _typeIcon(type);

    return Dismissible(
      key: Key(docId),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteNotification(docId),
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: Colors.red,
            borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.delete_rounded, color: Colors.white, size: 24),
          SizedBox(height: 4),
          Text('Delete', style: TextStyle(color: Colors.white,
              fontSize: 11, fontWeight: FontWeight.bold)),
        ]),
      ),
      child: GestureDetector(
        onTap: () { if (isUnread) _markRead(docId); },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isUnread ? Border.all(color: color.withOpacity(0.3), width: 1.5) : null,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
                blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(
                    notification['title'] as String? ?? '',
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                        color: const Color(0xFF1A1A2E)),
                  )),
                  if (isImportant) Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6)),
                    child: const Text('Important', style: TextStyle(
                        fontSize: 9, color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(notification['body'] as String? ?? '',
                  style: GoogleFonts.poppins(fontSize: 12,
                      color: Colors.grey.shade600, height: 1.4),
                  maxLines: 3, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(type, style: TextStyle(
                          fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    Text(_formatTime(notification['createdAt']),
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                  ]),
                  if (isUnread) Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                ]),
              ])),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 120, height: 120,
          decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(Icons.notifications_none_rounded, size: 60, color: AppColors.primary),
        ),
        const SizedBox(height: 24),
        Text('No Notifications Yet!', style: GoogleFonts.poppins(
            fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A2E))),
        const SizedBox(height: 8),
        Text('We will notify you about new jobs,\nexam dates and deadlines!',
            style: GoogleFonts.poppins(fontSize: 14,
                color: Colors.grey.shade500, height: 1.5),
            textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: 0,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: Colors.grey.shade400,
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
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.work_outline),
            activeIcon: Icon(Icons.work), label: 'Jobs'),
        BottomNavigationBarItem(icon: Icon(Icons.newspaper_outlined),
            activeIcon: Icon(Icons.newspaper), label: 'News'),
        BottomNavigationBarItem(icon: Icon(Icons.bookmark_outline),
            activeIcon: Icon(Icons.bookmark), label: 'Saved'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}
