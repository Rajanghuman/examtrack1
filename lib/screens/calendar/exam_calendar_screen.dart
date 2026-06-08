import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';

class ExamCalendarScreen extends StatefulWidget {
  const ExamCalendarScreen({super.key});

  @override
  State<ExamCalendarScreen> createState() =>
      _ExamCalendarScreenState();
}

class _ExamCalendarScreenState extends State<ExamCalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Map<DateTime, List<ExamEvent>> _events = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEventsFromFirestore();
  }

  // ── Load events from Firestore ─────────────────────────
  Future<void> _loadEventsFromFirestore() async {
    try {
      // Load from jobs collection — use lastDate and examDate
      final snapshot = await FirebaseFirestore.instance
          .collection('jobs')
          .get();

      final Map<DateTime, List<ExamEvent>> events = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final title = data['title'] as String? ?? '';
        final category = data['category'] as String? ?? '';
        final lastDate = data['lastDate'] as String?;
        final examDate = data['examDate'] as String?;
        final color = _categoryColor(category);

        // Add last date event
        if (lastDate != null && lastDate != 'TBA') {
          final date = _parseDate(lastDate);
          if (date != null) {
            final key =
            DateTime(date.year, date.month, date.day);
            events[key] = events[key] ?? [];
            events[key]!.add(ExamEvent(
              title,
              'Last Date to Apply',
              Colors.orange,
            ));
          }
        }

        // Add exam date event
        if (examDate != null && examDate != 'TBA') {
          final date = _parseDate(examDate);
          if (date != null) {
            final key =
            DateTime(date.year, date.month, date.day);
            events[key] = events[key] ?? [];
            events[key]!.add(ExamEvent(
              title,
              'Exam Date',
              color,
            ));
          }
        }
      }

      // Also load from events collection if exists
      try {
        final eventsSnapshot = await FirebaseFirestore.instance
            .collection('events')
            .get();

        for (final doc in eventsSnapshot.docs) {
          final data = doc.data();
          final name = data['examName'] as String? ?? '';
          final type = data['type'] as String? ?? '';
          final dateStr = data['date'] as String?;
          final colorHex = data['color'] as String?;

          if (dateStr != null && dateStr != 'TBA') {
            final date = _parseDate(dateStr);
            if (date != null) {
              final key =
              DateTime(date.year, date.month, date.day);
              final color = colorHex != null
                  ? Color(int.parse(colorHex))
                  : AppColors.primary;
              events[key] = events[key] ?? [];
              events[key]!.add(ExamEvent(name, type, color));
            }
          }
        }
      } catch (e) {
        // events collection might not exist yet
        print('No events collection: $e');
      }

      setState(() {
        _events = events;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading events: $e');
      setState(() => _isLoading = false);
    }
  }

  DateTime? _parseDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
      }
    } catch (e) {
      print('Error parsing date: $e');
    }
    return null;
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

  List<ExamEvent> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)]
        ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF1565C0)))
                : SingleChildScrollView(
              child: Column(
                children: [
                  _buildCalendar(),
                  _buildLegend(),
                  _buildSelectedDayEvents(),
                  _buildUpcomingEvents(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    final totalEvents = _events.values
        .fold(0, (sum, list) => sum + list.length);
    final thisMonthEvents = _events.entries
        .where((e) =>
    e.key.month == DateTime.now().month &&
        e.key.year == DateTime.now().year)
        .fold(0, (sum, e) => sum + e.value.length);

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
                  Text('Exam Calendar',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  Text('Track all your exam dates',
                      style: GoogleFonts.poppins(
                          color: Colors.white70, fontSize: 13)),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() => _isLoading = true);
                  _loadEventsFromFirestore();
                },
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
              _buildHeaderStat('$totalEvents',
                  'Total\nEvents'),
              const SizedBox(width: 24),
              _buildHeaderStat('$thisMonthEvents',
                  'This\nMonth'),
              const SizedBox(width: 24),
              _buildHeaderStat(
                  '${_events.length}', 'Active\nDates'),
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
                color: Colors.white, fontSize: 22,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: GoogleFonts.poppins(
                color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _buildCalendar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: TableCalendar(
        firstDay: DateTime(2026, 1, 1),
        lastDay: DateTime(2027, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        selectedDayPredicate: (day) =>
            isSameDay(_selectedDay, day),
        eventLoader: _getEventsForDay,
        startingDayOfWeek: StartingDayOfWeek.monday,
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          selectedDecoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle),
          todayDecoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.3),
              shape: BoxShape.circle),
          markerDecoration: const BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle),
          markersMaxCount: 3,
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: true,
          titleCentered: true,
          formatButtonDecoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          formatButtonTextStyle: TextStyle(
              color: AppColors.primary, fontSize: 12),
          titleTextStyle: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold),
          leftChevronIcon: Icon(Icons.chevron_left_rounded,
              color: AppColors.primary),
          rightChevronIcon: Icon(Icons.chevron_right_rounded,
              color: AppColors.primary),
        ),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onFormatChanged: (format) =>
            setState(() => _calendarFormat = format),
        onPageChanged: (focusedDay) =>
        _focusedDay = focusedDay,
      ),
    );
  }

  Widget _buildLegend() {
    final legends = [
      {'color': AppColors.railway, 'label': 'Exam Date'},
      {'color': Colors.orange, 'label': 'Last Date'},
      {'color': Colors.green, 'label': 'Admit Card'},
      {'color': Colors.purple, 'label': 'Result'},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06),
              blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: legends.map((legend) {
          return Row(
            children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                    color: legend['color'] as Color,
                    shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(legend['label'] as String,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w500)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSelectedDayEvents() {
    final events = _selectedDay != null
        ? _getEventsForDay(_selectedDay!)
        : <ExamEvent>[];

    if (events.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Text(
            'Events on ${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}',
            style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1A2E)),
          ),
        ),
        ...events.map((event) => _buildEventCard(event)),
      ],
    );
  }

  Widget _buildUpcomingEvents() {
    final allEvents = <MapEntry<DateTime, ExamEvent>>[];
    _events.forEach((date, events) {
      for (final event in events) {
        if (date.isAfter(DateTime.now())) {
          allEvents.add(MapEntry(date, event));
        }
      }
    });
    allEvents.sort((a, b) => a.key.compareTo(b.key));

    if (allEvents.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.event_busy_rounded,
                  size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text('No upcoming events',
                  style: GoogleFonts.poppins(
                      color: Colors.grey.shade500, fontSize: 14)),
              Text('Events will appear as jobs are updated',
                  style: GoogleFonts.poppins(
                      color: Colors.grey.shade400, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Text('Upcoming Events',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A2E))),
        ),
        ...allEvents.take(10).map((entry) {
          final daysLeft =
              entry.key.difference(DateTime.now()).inDays;
          return Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: entry.value.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${entry.key.day}',
                          style: TextStyle(
                              color: entry.value.color,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      Text(_getMonthName(entry.key.month),
                          style: TextStyle(
                              color: entry.value.color,
                              fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.value.name,
                          style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1A2E))),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: entry.value.color
                              .withOpacity(0.1),
                          borderRadius:
                          BorderRadius.circular(6),
                        ),
                        child: Text(entry.value.type,
                            style: TextStyle(
                                fontSize: 11,
                                color: entry.value.color,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: daysLeft <= 7
                        ? Colors.red.withOpacity(0.1)
                        : daysLeft <= 30
                        ? Colors.orange.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text('$daysLeft',
                          style: TextStyle(
                            color: daysLeft <= 7
                                ? Colors.red
                                : daysLeft <= 30
                                ? Colors.orange
                                : Colors.green,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          )),
                      Text('days',
                          style: TextStyle(
                            color: daysLeft <= 7
                                ? Colors.red
                                : daysLeft <= 30
                                ? Colors.orange
                                : Colors.green,
                            fontSize: 10,
                          )),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildEventCard(ExamEvent event) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: event.color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06),
              blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 8, height: 40,
            decoration: BoxDecoration(
                color: event.color,
                borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.name,
                    style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1A2E))),
                Text(event.type,
                    style: TextStyle(
                        fontSize: 12, color: event.color,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Icon(Icons.notifications_none_rounded,
              color: event.color),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: 2,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: Colors.grey.shade400,
      backgroundColor: Colors.white,
      elevation: 0,
      selectedFontSize: 11,
      unselectedFontSize: 11,
      onTap: (index) {
        switch (index) {
          case 0: Navigator.pushReplacementNamed(context, '/home'); break;
          case 1: Navigator.pushReplacementNamed(context, '/jobs'); break;
          case 2: Navigator.pushReplacementNamed(context, '/current-affairs'); break;
          case 3: Navigator.pushReplacementNamed(context, '/saved'); break;
          case 4: Navigator.pushReplacementNamed(context, '/profile'); break;
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.work_rounded), label: 'Jobs'),
        BottomNavigationBarItem(icon: Icon(Icons.newspaper_outlined), activeIcon: Icon(Icons.newspaper), label: 'News'),
        BottomNavigationBarItem(icon: Icon(Icons.bookmark_rounded), label: 'Saved'),
        BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}

class ExamEvent {
  final String name;
  final String type;
  final Color color;
  ExamEvent(this.name, this.type, this.color);
}