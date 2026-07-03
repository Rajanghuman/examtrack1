import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:examtrack/services/progress_service.dart';
import 'package:examtrack/widgets/progress_widgets.dart';

// ============================================================
// MockTestScreen — full Testbook-style mock test interface
//
// Features:
// - Question palette with color-coded status
// - Free navigation (jump to any question)
// - Mark for Review (with/without answer)
// - Clear Response
// - Section-wise tabs
// - Configurable marking scheme (+2/-0.5 default)
// - Countdown timer with red warning
// - Submit confirmation dialog
// - Detailed results screen
// - Solutions review screen
//
// Question data structure (from Firestore):
//   q['q']       — question text
//   q['opts']    — List<String> of 4 options
//   q['ans']     — int index of correct answer (0-3)
//   q['exp']     — explanation string
//   q['subject'] — section/subject name
//   q['id']      — question ID
// ============================================================

// Question status for palette color coding
enum QStatus {
  notVisited,    // ⚪ Grey
  notAnswered,   // 🔴 Red (visited but no answer)
  answered,      // 🟢 Green
  markedReview,  // 🟣 Purple (marked, no answer)
  answeredMarked // 🟡 Yellow (answered + marked)
}

class MockTestScreen extends StatefulWidget {
  final String examName;
  final String testTitle;
  final List<Map<String, dynamic>> questions;
  final int durationMinutes; // total test duration
  final double correctMarks;
  final double negativeMarks;

  const MockTestScreen({
    super.key,
    required this.examName,
    required this.testTitle,
    required this.questions,
    this.durationMinutes = 60,
    this.correctMarks = 2.0,
    this.negativeMarks = 0.5,
  });

  @override
  State<MockTestScreen> createState() => _MockTestScreenState();
}

class _MockTestScreenState extends State<MockTestScreen>
    with SingleTickerProviderStateMixin {
  // ── State ────────────────────────────────────────────────────
  int _currentIndex = 0;
  late List<int?> _selectedAnswers; // null = not answered
  late List<bool> _markedForReview;
  late List<bool> _visited;
  late List<Map<String, dynamic>> _questions;

  // Timer
  late int _secondsLeft;
  Timer? _timer;
  bool _submitted = false;

  // Results
  bool _showResults = false;
  bool _showSolutions = false;

  // Marking scheme (modifiable)
  late double _correctMarks;
  late double _negativeMarks;

  // Section tabs
  late TabController _tabController;
  late List<String> _sections;
  late Map<String, List<int>> _sectionIndices; // section -> question indices

  // Palette visibility on mobile
  bool _showPalette = false;

  static const Color _primary = Color(0xFF1565C0);

  @override
  void initState() {
    super.initState();
    _questions = widget.questions;
    _selectedAnswers = List.filled(_questions.length, null);
    _markedForReview = List.filled(_questions.length, false);
    _visited = List.filled(_questions.length, false);
    _secondsLeft = widget.durationMinutes * 60;
    _correctMarks = widget.correctMarks;
    _negativeMarks = widget.negativeMarks;

    // Build section map
    _buildSections();
    _tabController = TabController(length: _sections.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
      final sectionName = _sections[_tabController.index];
      final firstQ = _sectionIndices[sectionName]!.first;
      _navigateTo(firstQ);
    });

    // Mark first question as visited
    _visited[0] = true;

    // Start timer
    _startTimer();
  }

  void _buildSections() {
    _sectionIndices = {};
    for (int i = 0; i < _questions.length; i++) {
      final subject = _questions[i]['subject'] as String? ?? 'General';
      _sectionIndices.putIfAbsent(subject, () => []).add(i);
    }
    _sections = _sectionIndices.keys.toList();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        _submitTest(autoSubmit: true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  // ── Navigation ────────────────────────────────────────────────
  void _navigateTo(int index) {
    setState(() {
      _currentIndex = index;
      if (!_visited[index]) _visited[index] = true;
      _showPalette = false;

      // Update section tab
      final subject = _questions[index]['subject'] as String? ?? 'General';
      final sectionIdx = _sections.indexOf(subject);
      if (sectionIdx >= 0 && _tabController.index != sectionIdx) {
        _tabController.animateTo(sectionIdx);
      }
    });
  }

  void _goNext() {
    if (_currentIndex < _questions.length - 1) {
      _navigateTo(_currentIndex + 1);
    }
  }

  void _goPrev() {
    if (_currentIndex > 0) {
      _navigateTo(_currentIndex - 1);
    }
  }

  // ── Answer actions ────────────────────────────────────────────
  void _selectAnswer(int optionIndex) {
    setState(() => _selectedAnswers[_currentIndex] = optionIndex);
  }

  void _clearResponse() {
    setState(() => _selectedAnswers[_currentIndex] = null);
  }

  void _toggleMarkForReview() {
    setState(() => _markedForReview[_currentIndex] = !_markedForReview[_currentIndex]);
  }

  void _saveAndNext() {
    _goNext();
  }

  // ── Question status ───────────────────────────────────────────
  QStatus _statusOf(int index) {
    if (!_visited[index]) return QStatus.notVisited;
    final answered = _selectedAnswers[index] != null;
    final marked = _markedForReview[index];
    if (answered && marked) return QStatus.answeredMarked;
    if (answered) return QStatus.answered;
    if (marked) return QStatus.markedReview;
    return QStatus.notAnswered;
  }

  Color _statusColor(QStatus status) {
    switch (status) {
      case QStatus.notVisited:    return Colors.grey.shade300;
      case QStatus.notAnswered:   return const Color(0xFFEF5350);
      case QStatus.answered:      return const Color(0xFF10B981);
      case QStatus.markedReview:  return const Color(0xFF7B1FA2);
      case QStatus.answeredMarked:return const Color(0xFFFFC107);
    }
  }

  // ── Submit ────────────────────────────────────────────────────
  void _showSubmitDialog() {
    final answered = _selectedAnswers.where((a) => a != null).length;
    final notAnswered = _selectedAnswers.where((a) => a == null).length -
        _markedForReview.where((m) => m).length;
    final markedWithAnswer = List.generate(_questions.length,
        (i) => _markedForReview[i] && _selectedAnswers[i] != null).where((x) => x).length;
    final markedWithout = _markedForReview.where((m) => m).length - markedWithAnswer;
    final notVisited = _visited.where((v) => !v).length;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Submit Test?', style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700, fontSize: 18)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _summaryRow('🟢 Answered', answered, const Color(0xFF10B981)),
          _summaryRow('🔴 Not Answered', notAnswered.clamp(0, _questions.length),
              const Color(0xFFEF5350)),
          _summaryRow('🟣 Marked for Review', markedWithout, const Color(0xFF7B1FA2)),
          _summaryRow('🟡 Answered + Marked', markedWithAnswer, const Color(0xFFFFC107)),
          _summaryRow('⚪ Not Visited', notVisited, Colors.grey),
          if (notAnswered > 0 || notVisited > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '⚠️ You have ${notAnswered + notVisited} unanswered questions.',
                style: GoogleFonts.poppins(fontSize: 11,
                    color: const Color(0xFF92400E)),
              ),
            ),
          ],
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Go Back', style: GoogleFonts.poppins(
                color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitTest();
            },
            style: ElevatedButton.styleFrom(backgroundColor: _primary),
            child: Text('Submit Test', style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, int count, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Text(label, style: GoogleFonts.poppins(fontSize: 13)),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10)),
        child: Text('$count', style: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ),
    ]),
  );

  Future<void> _submitTest({bool autoSubmit = false}) async {
    _timer?.cancel();
    setState(() {
      _submitted = true;
      _showResults = true;
    });

    // Award XP
    final result = await ProgressService.awardXP(
        'mock_test_completed', ProgressService.xpMockCompleted);
    if (mounted && result.hasUpdate) {
      ProgressWidgets.handleResult(context, result);
    }
    ProgressService.addExamHistory(
        examName: widget.examName, status: 'appeared', source: 'app');
  }

  // ── Score calculation ─────────────────────────────────────────
  double get _totalScore {
    double score = 0;
    for (int i = 0; i < _questions.length; i++) {
      final selected = _selectedAnswers[i];
      if (selected == null) continue;
      final correct = _questions[i]['ans'] as int;
      if (selected == correct) {
        score += _correctMarks;
      } else {
        score -= _negativeMarks;
      }
    }
    return score;
  }

  int get _correctCount => List.generate(_questions.length,
      (i) => _selectedAnswers[i] == _questions[i]['ans']).where((x) => x).length;

  int get _incorrectCount => List.generate(_questions.length,
      (i) => _selectedAnswers[i] != null &&
          _selectedAnswers[i] != _questions[i]['ans']).where((x) => x).length;

  int get _unattemptedCount =>
      _selectedAnswers.where((a) => a == null).length;

  double get _maxScore => _questions.length * _correctMarks;

  // ── Timer display ─────────────────────────────────────────────
  String get _timerDisplay {
    final h = _secondsLeft ~/ 3600;
    final m = (_secondsLeft % 3600) ~/ 60;
    final s = _secondsLeft % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  bool get _isTimeCritical => _secondsLeft <= 300; // last 5 mins

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_showSolutions) return _buildSolutionsScreen();
    if (_showResults) return _buildResultsScreen();
    return _buildTestScreen();
  }

  // ── Test Screen ───────────────────────────────────────────────
  Widget _buildTestScreen() {
    final q = _questions[_currentIndex];
    final opts = (q['opts'] as List).cast<String>();
    final selected = _selectedAnswers[_currentIndex];
    final marked = _markedForReview[_currentIndex];

    return PopScope(
      canPop: false,
      onPopInvoked: (_) => _showSubmitDialog(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Column(children: [
          _buildTopBar(),
          _buildSectionTabs(),
          Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Main question area
            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Question number + subject tag
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Q ${_currentIndex + 1}',
                        style: GoogleFonts.poppins(fontSize: 12,
                            fontWeight: FontWeight.w700, color: _primary)),
                  ),
                  const SizedBox(width: 8),
                  if (q['subject'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7B1FA2).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(q['subject'] as String,
                          style: GoogleFonts.poppins(fontSize: 11,
                              color: const Color(0xFF7B1FA2),
                              fontWeight: FontWeight.w600)),
                    ),
                  const Spacer(),
                  // Mark for review toggle
                  GestureDetector(
                    onTap: _toggleMarkForReview,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: marked
                            ? const Color(0xFF7B1FA2)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: marked ? const Color(0xFF7B1FA2) : Colors.grey.shade300),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(marked ? Icons.bookmark : Icons.bookmark_border,
                            size: 14,
                            color: marked ? Colors.white : Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(marked ? 'Marked' : 'Mark',
                            style: GoogleFonts.poppins(fontSize: 11,
                                color: marked ? Colors.white : Colors.grey.shade500,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),

                // Question text
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
                  ),
                  child: Text(q['q'] as String,
                      style: GoogleFonts.poppins(fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1A1A2E), height: 1.5)),
                ),
                const SizedBox(height: 14),

                // Options
                ...List.generate(opts.length, (i) {
                  final isSelected = selected == i;
                  final optLabel = ['A', 'B', 'C', 'D'][i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: () => _selectAnswer(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected ? _primary.withOpacity(0.06) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? _primary : Colors.grey.shade300,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(children: [
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: isSelected ? _primary : Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Center(child: Text(optLabel,
                                style: GoogleFonts.poppins(
                                    fontSize: 12, fontWeight: FontWeight.w700,
                                    color: isSelected ? Colors.white : Colors.grey.shade600))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(opts[i],
                              style: GoogleFonts.poppins(fontSize: 13,
                                  color: const Color(0xFF374151),
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal))),
                          if (isSelected)
                            Icon(Icons.radio_button_checked, color: _primary, size: 18),
                        ]),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),

                // Action buttons row
                Row(children: [
                  // Clear response
                  if (selected != null)
                    Expanded(child: OutlinedButton(
                      onPressed: _clearResponse,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF5350),
                        side: const BorderSide(color: Color(0xFFEF5350)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Clear', style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                    )),
                  if (selected != null) const SizedBox(width: 8),
                  // Save & Next
                  Expanded(flex: selected != null ? 2 : 1, child: ElevatedButton(
                    onPressed: _goNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      _currentIndex < _questions.length - 1
                          ? 'Save & Next →' : 'Review & Submit',
                      style: GoogleFonts.poppins(color: Colors.white,
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  )),
                ]),
                const SizedBox(height: 12),

                // Prev / Next navigation
                Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: _currentIndex > 0 ? _goPrev : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primary,
                      side: BorderSide(color: _primary.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('← Previous', style: GoogleFonts.poppins(fontSize: 12)),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton(
                    onPressed: _currentIndex < _questions.length - 1 ? _goNext : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primary,
                      side: BorderSide(color: _primary.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('Next →', style: GoogleFonts.poppins(fontSize: 12)),
                  )),
                ]),
                const SizedBox(height: 20),

                // Question palette (always visible on larger screens, toggle on mobile)
                _buildPaletteSection(),
                const SizedBox(height: 80),
              ]),
            )),
          ])),

          // Bottom bar
          _buildBottomBar(),
        ]),
      ),
    );
  }

  Widget _buildTopBar() => Container(
    color: _primary,
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 6,
      left: 12, right: 12, bottom: 10,
    ),
    child: Row(children: [
      GestureDetector(
        onTap: _showSubmitDialog,
        child: const Icon(Icons.close, color: Colors.white, size: 20),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.testTitle,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 13,
                fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis),
        Text('Q ${_currentIndex + 1} of ${_questions.length}',
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 10)),
      ])),
      // Timer
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _isTimeCritical
              ? const Color(0xFFEF5350)
              : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.timer, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(_timerDisplay,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
      const SizedBox(width: 8),
      // Submit button
      GestureDetector(
        onTap: _showSubmitDialog,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('Submit', style: GoogleFonts.poppins(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ),
    ]),
  );

  Widget _buildSectionTabs() {
    if (_sections.length <= 1) return const SizedBox.shrink();
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: _primary,
        labelColor: _primary,
        unselectedLabelColor: Colors.grey.shade500,
        labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
        tabs: _sections.map((s) {
          final indices = _sectionIndices[s]!;
          final answered = indices.where((i) => _selectedAnswers[i] != null).length;
          return Tab(text: '$s ($answered/${indices.length})');
        }).toList(),
      ),
    );
  }

  Widget _buildPaletteSection() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Question Palette', style: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E))),
        const Spacer(),
        // Legend
        _legendItem('Answered', const Color(0xFF10B981)),
        const SizedBox(width: 8),
        _legendItem('Not Ans', const Color(0xFFEF5350)),
        const SizedBox(width: 8),
        _legendItem('Marked', const Color(0xFF7B1FA2)),
      ]),
      const SizedBox(height: 12),
      Wrap(
        spacing: 6, runSpacing: 6,
        children: List.generate(_questions.length, (i) {
          final status = _statusOf(i);
          final color = _statusColor(status);
          final isCurrent = i == _currentIndex;
          return GestureDetector(
            onTap: () => _navigateTo(i),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: isCurrent ? color : color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isCurrent ? _primary : color,
                  width: isCurrent ? 2 : 1,
                ),
              ),
              child: Center(child: Text('${i + 1}',
                  style: GoogleFonts.poppins(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: isCurrent ? Colors.white : color))),
            ),
          );
        }),
      ),
    ]),
  );

  Widget _legendItem(String label, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 3),
    Text(label, style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey.shade500)),
  ]);

  Widget _buildBottomBar() => Container(
    padding: EdgeInsets.only(
      left: 16, right: 16, top: 10,
      bottom: MediaQuery.of(context).padding.bottom + 10,
    ),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, -2))],
    ),
    child: Row(children: [
      Text(
        '✅ ${_selectedAnswers.where((a) => a != null).length}  '
        '❌ ${_selectedAnswers.where((a) => a == null).length}  '
        '🔖 ${_markedForReview.where((m) => m).length}',
        style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500),
      ),
      const Spacer(),
      Text('${widget.examName}',
          style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade400),
          overflow: TextOverflow.ellipsis),
    ]),
  );

  // ── Results Screen ────────────────────────────────────────────
  Widget _buildResultsScreen() {
    final score = _totalScore;
    final pct = (_correctCount / _questions.length * 100).round();
    final color = pct >= 70 ? const Color(0xFF10B981)
        : pct >= 50 ? const Color(0xFFF59E0B) : const Color(0xFFEF5350);

    // Section-wise breakdown
    final Map<String, int> sectionCorrect = {};
    final Map<String, int> sectionTotal = {};
    for (int i = 0; i < _questions.length; i++) {
      final subject = _questions[i]['subject'] as String? ?? 'General';
      sectionTotal[subject] = (sectionTotal[subject] ?? 0) + 1;
      if (_selectedAnswers[i] == _questions[i]['ans']) {
        sectionCorrect[subject] = (sectionCorrect[subject] ?? 0) + 1;
      }
    }

    final timeTaken = widget.durationMinutes * 60 - _secondsLeft;
    final mins = timeTaken ~/ 60;
    final secs = timeTaken % 60;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(children: [
        // Header
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withOpacity(0.7)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16, right: 16, bottom: 24,
          ),
          child: Column(children: [
            Text(widget.testTitle, style: GoogleFonts.poppins(
                color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 16),
            // Score circle
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('${score.toStringAsFixed(1)}',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 26,
                        fontWeight: FontWeight.w900)),
                Text('/ ${_maxScore.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 12),
            Text('$pct% Score', style: GoogleFonts.poppins(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            Text(pct >= 70 ? '🎉 Excellent!' : pct >= 50 ? '👍 Good Effort!' : '💪 Keep Practicing!',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
          ]),
        ),

        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            // Stats row
            Row(children: [
              _resultStat('✅', '$_correctCount', 'Correct', const Color(0xFF10B981)),
              const SizedBox(width: 8),
              _resultStat('❌', '$_incorrectCount', 'Wrong', const Color(0xFFEF5350)),
              const SizedBox(width: 8),
              _resultStat('⭕', '$_unattemptedCount', 'Skipped', Colors.grey),
              const SizedBox(width: 8),
              _resultStat('⏱', '${mins}m ${secs}s', 'Time', _primary),
            ]),
            const SizedBox(height: 16),

            // Marking scheme info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(children: [
                const Text('📊', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Text('+$_correctMarks per correct  •  -$_negativeMarks per wrong',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
              ]),
            ),
            const SizedBox(height: 16),

            // Section-wise breakdown
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Section-wise Performance', style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A2E))),
                const SizedBox(height: 12),
                ...sectionTotal.entries.map((entry) {
                  final section = entry.key;
                  final total = entry.value;
                  final correct = sectionCorrect[section] ?? 0;
                  final sectionPct = (correct / total * 100).round();
                  final sColor = sectionPct >= 70 ? const Color(0xFF10B981)
                      : sectionPct >= 50 ? const Color(0xFFF59E0B) : const Color(0xFFEF5350);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(section, style: GoogleFonts.poppins(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: const Color(0xFF374151))),
                        const Spacer(),
                        Text('$correct/$total',
                            style: GoogleFonts.poppins(fontSize: 12,
                                fontWeight: FontWeight.w700, color: sColor)),
                      ]),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: correct / total,
                          backgroundColor: Colors.grey.shade100,
                          valueColor: AlwaysStoppedAnimation(sColor),
                          minHeight: 7,
                        ),
                      ),
                    ]),
                  );
                }),
              ]),
            ),
            const SizedBox(height: 20),

            // View Solutions button
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: () => setState(() => _showSolutions = true),
              icon: const Icon(Icons.menu_book, color: Colors.white, size: 18),
              label: Text('View Solutions & Explanations',
                  style: GoogleFonts.poppins(color: Colors.white,
                      fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B1FA2),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primary,
                side: const BorderSide(color: _primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Back to Tests', style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w600)),
            )),
            const SizedBox(height: 40),
          ]),
        )),
      ]),
    );
  }

  Widget _resultStat(String emoji, String value, String label, Color color) =>
    Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.poppins(fontSize: 14,
            fontWeight: FontWeight.w800, color: color)),
        Text(label, style: GoogleFonts.poppins(fontSize: 9,
            color: Colors.grey.shade500)),
      ]),
    ));

  // ── Solutions Screen ──────────────────────────────────────────
  Widget _buildSolutionsScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7B1FA2),
        title: Text('Solutions', style: GoogleFonts.poppins(
            color: Colors.white, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => setState(() => _showSolutions = false),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: Text('${_questions.length} Questions',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12))),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _questions.length,
        itemBuilder: (_, i) {
          final q = _questions[i];
          final opts = (q['opts'] as List).cast<String>();
          final correct = q['ans'] as int;
          final selected = _selectedAnswers[i];
          final isCorrect = selected == correct;
          final isSkipped = selected == null;

          Color headerColor;
          String statusLabel;
          if (isSkipped) {
            headerColor = Colors.grey;
            statusLabel = 'Skipped';
          } else if (isCorrect) {
            headerColor = const Color(0xFF10B981);
            statusLabel = 'Correct';
          } else {
            headerColor = const Color(0xFFEF5350);
            statusLabel = 'Wrong';
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: headerColor.withOpacity(0.3)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Question header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: headerColor.withOpacity(0.08),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Row(children: [
                  Text('Q${i + 1}', style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w700, color: headerColor)),
                  const SizedBox(width: 8),
                  if (q['subject'] != null)
                    Text(q['subject'] as String, style: GoogleFonts.poppins(
                        fontSize: 11, color: Colors.grey.shade500)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: headerColor, borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(statusLabel, style: GoogleFonts.poppins(
                        fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),

              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(q['q'] as String, style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w500,
                      color: const Color(0xFF1A1A2E), height: 1.4)),
                  const SizedBox(height: 12),

                  // Options
                  ...List.generate(opts.length, (j) {
                    final isCorrectOpt = j == correct;
                    final isSelectedOpt = j == selected;
                    Color bg = Colors.transparent;
                    Color border = Colors.grey.shade200;
                    Color text = const Color(0xFF374151);

                    if (isCorrectOpt) {
                      bg = const Color(0xFFE8F5E9);
                      border = const Color(0xFF10B981);
                      text = const Color(0xFF065F46);
                    } else if (isSelectedOpt && !isCorrectOpt) {
                      bg = const Color(0xFFFFEBEE);
                      border = const Color(0xFFEF5350);
                      text = const Color(0xFFC62828);
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: bg, borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: border),
                      ),
                      child: Row(children: [
                        Text(['A', 'B', 'C', 'D'][j],
                            style: GoogleFonts.poppins(fontSize: 12,
                                fontWeight: FontWeight.w700, color: border)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(opts[j],
                            style: GoogleFonts.poppins(fontSize: 12, color: text))),
                        if (isCorrectOpt)
                          const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                        if (isSelectedOpt && !isCorrectOpt)
                          const Icon(Icons.cancel, color: Color(0xFFEF5350), size: 16),
                      ]),
                    );
                  }),

                  // Explanation
                  if (q['exp'] != null && (q['exp'] as String).isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFC107).withOpacity(0.4)),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('💡', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(q['exp'] as String,
                            style: GoogleFonts.poppins(fontSize: 11,
                                color: const Color(0xFF92400E), height: 1.4))),
                      ]),
                    ),
                  ],
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }
}
