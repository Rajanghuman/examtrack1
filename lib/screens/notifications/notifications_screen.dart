import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState
    extends State<NotificationsScreen> {
  String _selectedFilter = 'All';
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];

  final List<String> _filters = [
    'All', 'Jobs', 'Exams', 'Results',
    'Admit Cards', 'Deadlines',
  ];

  // ── Seed notifications shown to new users ──────────────
  static final List<Map<String, dynamic>> _seedNotifications = [
    {
      'title': 'New Job Alert! 🎉',
      'body': 'Railway RRB NTPC 2026 has released 11,558 vacancies. Last date to apply is 30 Jun 2026.',
      'type': 'Jobs',
      'isRead': false,
      'isImportant': true,
      'createdAt': Timestamp.now(),
    },
    {
      'title': 'Deadline Reminder ⚠️',
      'body': 'SSC CGL 2026 application deadline is in 3 days! Apply before 31 May 2026.',
      'type': 'Deadlines',
      'isRead': false,
      'isImportant': true,
      'createdAt': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(hours: 1))),
    },
    {
      'title': 'Admit Card Released! 📄',
      'body': 'Army GD 2026 admit card has been released. Download from joinindianarmy.nic.in',
      'type': 'Admit Cards',
      'isRead': false,
      'isImportant': false,
      'createdAt': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(hours: 3))),
    },
    {
      'title': 'Exam Date Announced 📅',
      'body': 'Punjab Police Constable written exam scheduled for 20 Aug 2026.',
      'type': 'Exams',
      'isRead': true,
      'isImportant': false,
      'createdAt': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(hours: 5))),
    },
    {
      'title': 'Result Declared! 🏆',
      'body': 'SSC CHSL Tier 1 result has been declared. Check your score at ssc.nic.in',
      'type': 'Results',
      'isRead': true,
      'isImportant': false,
      'createdAt': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(days: 1))),
    },
    {
      'title': 'New Job Alert! 🎉',
      'body': 'IBPS PO 2026 notification released. 4,455 vacancies for Probationary Officers.',
      'type': 'Jobs',
      'isRead': true,
      'isImportant': false,
      'createdAt': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(days: 1, hours: 2))),
    },
    {
      'title': 'Deadline Reminder ⚠️',
      'body': 'Punjab Police Constable application closing in 7 days. Last date: 15 Jul 2026.',
      'type': 'Deadlines',
      'isRead': true,
      'isImportant': false,
      'createdAt': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(days: 2))),
    },
    {
      'title': 'New Vacancy Alert! 🎉',
      'body': 'Army GD 2026 has released 25,000+ vacancies. Apply before 10 Jul 2026.',
      'type': 'Jobs',
      'isRead': true,
      'isImportant': false,
      'createdAt': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(days: 3))),
    },
    {
      'title': 'Cut Off Released 📊',
      'body': 'SSC CGL 2025 final cut off marks released. General: 165.5, OBC: 155.25',
      'type': 'Results',
      'isRead': true,
      'isImportant': false,
      'createdAt': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(days: 7))),
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  // ── Load notifications from Firestore ──────────────────
  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final colRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications');

      final snapshot = await colRef
          .orderBy('createdAt', descending: true)
          .get();

      // Seed if empty
      if (snapshot.docs.isEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (final n in _seedNotifications) {
          batch.set(colRef.doc(), n);
        }
        await batch.commit();

        // Reload after seeding
        final seeded = await colRef
            .orderBy('createdAt', descending: true)
            .get();
        _setNotifications(seeded);
      } else {
        _setNotifications(snapshot);
      }
    } catch (e) {
      print('Error loading notifications: $e');
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

  // ── Mark single notification as read ──────────────────
  Future<void> _markRead(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .doc(docId)
        .update({'isRead': true});
    setState(() {
      final idx = _notifications.indexWhere(
              (n) => n['id'] == docId);
      if (idx != -1) _notifications[idx]['isRead'] = true;
    });
  }

  // ── Mark all as read ───────────────────────────────────
  Future<void> _markAllRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final n in _notifications) {
      if (n['isRead'] == false) {
        final ref = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .doc(n['id'] as String);
        batch.update(ref, {'isRead': true});
      }
    }
    await batch.commit();
    setState(() {
      for (final n in _notifications) {
        n['isRead'] = true;
      }
    });
  }

  // ── Delete notification ────────────────────────────────
  Future<void> _deleteNotification(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .doc(docId)
        .delete();
    setState(() {
      _notifications.removeWhere((n) => n['id'] == docId);
    });
  }

  // ── Helpers ────────────────────────────────────────────
  List<Map<String, dynamic>> get _filteredNotifications {
    if (_selectedFilter == 'All') return _notifications;
    return _notifications
        .where((n) => n['type'] == _selectedFilter)
        .toList();
  }

  int get _unreadCount =>
      _notifications.where((n) => n['isRead'] == false).length;

  Color _typeColor(String type) {
    switch (type) {
      case 'Jobs':        return AppColors.primary;
      case 'Exams':       return AppColors.railway;
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
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24)   return '${diff.inHours}h ago';
      if (diff.inDays == 1)    return 'Yesterday';
      if (diff.inDays < 7)     return '${diff.inDays} days ago';
      return '1 week ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          _buildFilterChips(),
          Expanded(
            child: _isLoading
                ? const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF1565C0)))
                : _filteredNotifications.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _loadNotifications,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount:
                _filteredNotifications.length,
                itemBuilder: (context, index) =>
                    _buildNotificationCard(
                        _filteredNotifications[index]),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    final jobCount = _notifications
        .where((n) => n['type'] == 'Jobs').length;
    final deadlineCount = _notifications
        .where((n) => n['type'] == 'Deadlines').length;
    final importantCount = _notifications
        .where((n) => n['isImportant'] == true).length;

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
            mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
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
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text('Notifications',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      Text('$_unreadCount unread notifications',
                          style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 13)),
                    ],
                  ),
                ],
              ),
              if (_unreadCount > 0)
                GestureDetector(
                  onTap: _markAllRead,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Mark all read',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildHeaderStat('$_unreadCount', 'Unread'),
              const SizedBox(width: 24),
              _buildHeaderStat('$jobCount', 'Job Alerts'),
              const SizedBox(width: 24),
              _buildHeaderStat('$deadlineCount', 'Deadlines'),
              const SizedBox(width: 24),
              _buildHeaderStat('$importantCount', 'Important'),
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
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: GoogleFonts.poppins(
                color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _buildFilterChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding:
        const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: _filters.map((filter) {
            final isSelected = _selectedFilter == filter;
            final count = filter == 'All'
                ? _notifications.length
                : _notifications
                .where((n) => n['type'] == filter)
                .length;
            return GestureDetector(
              onTap: () =>
                  setState(() => _selectedFilter = filter),
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
                child: Row(
                  children: [
                    Text(filter,
                        style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withOpacity(0.3)
                            : Colors.grey.shade300,
                        borderRadius:
                        BorderRadius.circular(10),
                      ),
                      child: Text('$count',
                          style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey.shade600,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
      Map<String, dynamic> notification) {
    final String docId = notification['id'] as String? ?? '';
    final String type =
        notification['type'] as String? ?? 'Jobs';
    final bool isUnread =
        notification['isRead'] == false;
    final bool isImportant =
        notification['isImportant'] == true;
    final Color color = _typeColor(type);
    final IconData icon = _typeIcon(type);

    return Dismissible(
      key: Key(docId),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteNotification(docId),
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_rounded,
                color: Colors.white, size: 24),
            SizedBox(height: 4),
            Text('Delete',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      child: GestureDetector(
        onTap: () {
          if (isUnread) _markRead(docId);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isUnread
                ? Border.all(
                color: color.withOpacity(0.3),
                width: 1.5)
                : null,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius:
                    BorderRadius.circular(12),
                  ),
                  child: Icon(icon,
                      color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification['title']
                              as String? ?? '',
                              style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: isUnread
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  color: const Color(
                                      0xFF1A1A2E)),
                            ),
                          ),
                          if (isImportant)
                            Container(
                              padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red
                                    .withOpacity(0.1),
                                borderRadius:
                                BorderRadius.circular(6),
                              ),
                              child: const Text('Important',
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.red,
                                      fontWeight:
                                      FontWeight.bold)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification['body']
                        as String? ?? '',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            height: 1.4),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets
                                    .symmetric(
                                    horizontal: 8,
                                    vertical: 3),
                                decoration: BoxDecoration(
                                  color:
                                  color.withOpacity(0.1),
                                  borderRadius:
                                  BorderRadius.circular(
                                      6),
                                ),
                                child: Text(type,
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: color,
                                        fontWeight:
                                        FontWeight.w600)),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatTime(
                                    notification['createdAt']),
                                style: TextStyle(
                                    fontSize: 11,
                                    color:
                                    Colors.grey.shade400),
                              ),
                            ],
                          ),
                          if (isUnread)
                            Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_none_rounded,
                size: 60, color: AppColors.primary),
          ),
          const SizedBox(height: 24),
          Text('No Notifications Yet!',
              style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A2E))),
          const SizedBox(height: 8),
          Text(
              'We will notify you about new jobs,\nexam dates and deadlines!',
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                  height: 1.5),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: 0,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: Colors.grey.shade400,
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