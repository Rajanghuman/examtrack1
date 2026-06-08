import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';

class AgeCalculatorScreen extends StatefulWidget {
  const AgeCalculatorScreen({super.key});

  @override
  State<AgeCalculatorScreen> createState() => _AgeCalculatorScreenState();
}

class _AgeCalculatorScreenState extends State<AgeCalculatorScreen> {
  DateTime? _selectedDOB;
  DateTime _currentDate = DateTime.now();
  bool _isLoadingDOB = true;

  int _years = 0;
  int _months = 0;
  int _days = 0;
  int _totalDays = 0;
  int _totalMonths = 0;
  int _totalWeeks = 0;
  bool _hasCalculated = false;

  final List<Map<String, dynamic>> _examCutoffs = [
    {
      'exam': 'SSC CGL 2026',
      'cutoffDate': DateTime(2026, 1, 1),
      'minAge': 18,
      'maxAge': 32,
      'category': 'SSC',
      'color': AppColors.ssc,
    },
    {
      'exam': 'Railway RRB NTPC',
      'cutoffDate': DateTime(2026, 1, 1),
      'minAge': 18,
      'maxAge': 33,
      'category': 'Railway',
      'color': AppColors.railway,
    },
    {
      'exam': 'Punjab Police Constable',
      'cutoffDate': DateTime(2026, 1, 1),
      'minAge': 18,
      'maxAge': 28,
      'category': 'Police',
      'color': AppColors.police,
    },
    {
      'exam': 'IBPS PO 2026',
      'cutoffDate': DateTime(2026, 1, 1),
      'minAge': 20,
      'maxAge': 30,
      'category': 'Banking',
      'color': AppColors.banking,
    },
    {
      'exam': 'Army GD 2026',
      'cutoffDate': DateTime(2026, 10, 1),
      'minAge': 17,
      'maxAge': 21,
      'category': 'Army',
      'color': AppColors.army,
    },
    {
      'exam': 'UPSC CSE 2026',
      'cutoffDate': DateTime(2026, 6, 1),
      'minAge': 21,
      'maxAge': 32,
      'category': 'UPSC',
      'color': AppColors.upsc,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadDOBFromProfile();
  }

  // ── Load DOB from Firebase profile ────────────────────
  Future<void> _loadDOBFromProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data();
          final dob = data?['dob'] as String?;
          if (dob != null && dob.isNotEmpty) {
            final parsed = _parseDOB(dob);
            if (parsed != null) {
              setState(() {
                _selectedDOB = parsed;
                _isLoadingDOB = false;
              });
              _calculateAge();
              return;
            }
          }
        }
      }
    } catch (e) {
      print('Error loading DOB: $e');
    }
    setState(() => _isLoadingDOB = false);
  }

  // ── Parse DOB from DD/MM/YYYY format ──────────────────
  DateTime? _parseDOB(String dob) {
    try {
      final parts = dob.split('/');
      if (parts.length == 3) {
        return DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
      }
    } catch (e) {
      print('Error parsing DOB: $e');
    }
    return null;
  }

  void _calculateAge() {
    if (_selectedDOB == null) return;

    final dob = _selectedDOB!;
    final now = _currentDate;

    int years = now.year - dob.year;
    int months = now.month - dob.month;
    int days = now.day - dob.day;

    if (days < 0) {
      months--;
      days += DateTime(now.year, now.month, 0).day;
    }
    if (months < 0) {
      years--;
      months += 12;
    }

    final totalDays = now.difference(dob).inDays;

    setState(() {
      _years = years;
      _months = months;
      _days = days;
      _totalDays = totalDays;
      _totalMonths = (years * 12) + months;
      _totalWeeks = (totalDays / 7).floor();
      _hasCalculated = true;
    });
  }

  int _calculateAgeAtDate(DateTime dob, DateTime cutoffDate) {
    int age = cutoffDate.year - dob.year;
    if (cutoffDate.month < dob.month ||
        (cutoffDate.month == dob.month && cutoffDate.day < dob.day)) {
      age--;
    }
    return age;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoadingDOB
                ? const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF1565C0)))
                : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildDOBSelector(),
                  const SizedBox(height: 20),
                  if (_hasCalculated) ...[
                    _buildAgeResult(),
                    const SizedBox(height: 20),
                    _buildDetailedStats(),
                    const SizedBox(height: 20),
                    _buildExamEligibility(),
                    const SizedBox(height: 80),
                  ],
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
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pushReplacementNamed(context, '/home'),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Age Calculator',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.w700)),
              Text('Check your exam eligibility',
                  style: GoogleFonts.poppins(
                      color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDOBSelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Date of Birth',
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A2E))),
              const Spacer(),
              if (_selectedDOB != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Auto-filled from profile ✓',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: const Color(0xFF10B981),
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDOB ??
                    DateTime(2000, 1, 1),
                firstDate: DateTime(1960),
                lastDate: DateTime.now(),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: Color(0xFF1565C0),
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() => _selectedDOB = picked);
                _calculateAge();
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF1565C0).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cake_outlined,
                      color: Color(0xFF1565C0), size: 24),
                  const SizedBox(width: 12),
                  Text(
                    _selectedDOB != null
                        ? '${_selectedDOB!.day.toString().padLeft(2, '0')}/${_selectedDOB!.month.toString().padLeft(2, '0')}/${_selectedDOB!.year}'
                        : 'Tap to select your date of birth',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: _selectedDOB != null
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: _selectedDOB != null
                          ? const Color(0xFF1A1A2E)
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.edit_calendar_outlined,
                      color: Color(0xFF1565C0), size: 20),
                ],
              ),
            ),
          ),
          if (_selectedDOB != null) ...[
            const SizedBox(height: 8),
            Text(
              'Tap to change date',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: const Color(0xFF9CA3AF)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAgeResult() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF1565C0).withOpacity(0.3),
              blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          Text('Your Age',
              style: GoogleFonts.poppins(
                  color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ageBox('$_years', 'Years'),
              _ageBox('$_months', 'Months'),
              _ageBox('$_days', 'Days'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ageBox(String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(value,
              style: GoogleFonts.poppins(
                  color: Colors.white, fontSize: 32,
                  fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: GoogleFonts.poppins(
                color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildDetailedStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06),
              blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Detailed Stats',
              style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A2E))),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _statCard(
                  '$_totalDays', 'Total Days', Icons.today_outlined,
                  const Color(0xFF1565C0))),
              const SizedBox(width: 10),
              Expanded(child: _statCard(
                  '$_totalWeeks', 'Total Weeks',
                  Icons.calendar_view_week_outlined,
                  const Color(0xFF10B981))),
              const SizedBox(width: 10),
              Expanded(child: _statCard(
                  '$_totalMonths', 'Total Months',
                  Icons.calendar_month_outlined,
                  const Color(0xFFFF6B00))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(
      String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w800,
                  color: color)),
          Text(label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 10, color: const Color(0xFF6B7280))),
        ],
      ),
    );
  }

  Widget _buildExamEligibility() {
    if (_selectedDOB == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06),
              blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Exam Eligibility Check',
              style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A2E))),
          const SizedBox(height: 4),
          Text('Based on your date of birth',
              style: GoogleFonts.poppins(
                  fontSize: 12, color: const Color(0xFF6B7280))),
          const SizedBox(height: 16),
          ..._examCutoffs.map((exam) {
            final ageAtCutoff = _calculateAgeAtDate(
                _selectedDOB!, exam['cutoffDate'] as DateTime);
            final isEligible = ageAtCutoff >= (exam['minAge'] as int) &&
                ageAtCutoff <= (exam['maxAge'] as int);
            final Color catColor = exam['color'] as Color;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isEligible
                    ? const Color(0xFF10B981).withOpacity(0.05)
                    : const Color(0xFFEF4444).withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isEligible
                      ? const Color(0xFF10B981).withOpacity(0.3)
                      : const Color(0xFFEF4444).withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: catColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.work_outline,
                        color: catColor, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(exam['exam'] as String,
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1A1A2E))),
                        Text(
                          'Age limit: ${exam['minAge']}-${exam['maxAge']} years | Your age: $ageAtCutoff',
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isEligible
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isEligible ? 'Eligible ✓' : 'Not Eligible',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: Colors.white,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            );
          }),
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