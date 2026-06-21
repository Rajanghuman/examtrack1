import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:examtrack/screens/study/study_data.dart';
import 'package:examtrack/services/memory_box_service.dart';
import 'package:examtrack/services/mock_test_service.dart';

class StudyMaterialScreen extends StatefulWidget {
  const StudyMaterialScreen({super.key});
  @override
  State<StudyMaterialScreen> createState() => _StudyMaterialScreenState();
}

class _StudyMaterialScreenState extends State<StudyMaterialScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedExam = 'SSC CGL';
  final List<String> _exams = ['SSC CGL','SSC CHSL','RRB NTPC','Army Agniveer','Punjab Police','IBPS PO','UPSC CSE','Delhi Police','Haryana Police','NDA'];

  // PYQ state
  int _quizIndex = 0;
  String? _selAns;
  bool _showExp = false;
  int _score = 0;
  bool _quizStarted = false;

  // Mock test state — now Firestore-backed
  List<Map<String,dynamic>> _firestoreMocks = [];
  bool _mocksLoading = true;
  bool _mockLoadError = false;

  Map<String,dynamic>? _activeMock; // full test WITH questions, fetched on demand
  bool _activeMockLoading = false;
  int _mockIndex = 0;
  String? _mockAns;
  bool _mockShowExp = false;
  int _mockScore = 0;
  bool _mockDone = false;
  Map<int, bool> _mockAnswers = {};
  Timer? _timer;
  int _timeLeft = 0;
  bool _timedMode = false;

  List<Map<String,dynamic>> get _sections => StudyData.getSections(_selectedExam);
  List<Map<String,dynamic>> get _pyqs => StudyData.getPYQs(_selectedExam);
  List<Map<String,dynamic>> get _mocks => _firestoreMocks;
  List<Map<String,dynamic>> get _qr => StudyData.getQR(_selectedExam);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadMockTests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _resetQuiz() {
    setState(() {
      _quizStarted = false; _quizIndex = 0;
      _score = 0; _selAns = null; _showExp = false;
    });
  }

  // ── Firestore: load list of mock tests for current exam ──
  Future<void> _loadMockTests() async {
    setState(() {
      _mocksLoading = true;
      _mockLoadError = false;
    });
    try {
      final tests = await MockTestService.getMockTests(_selectedExam);
      if (!mounted) return;
      setState(() {
        _firestoreMocks = tests;
        _mocksLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mocksLoading = false;
        _mockLoadError = true;
      });
    }
  }

  void _resetMock() {
    _timer?.cancel();
    setState(() {
      _activeMock = null; _mockIndex = 0; _mockScore = 0;
      _mockAns = null; _mockShowExp = false; _mockDone = false;
      _mockAnswers = {};
    });
  }

  // ── Firestore: fetch full test (with questions) before starting ──
  Future<void> _startMockTest(Map<String,dynamic> testSummary, {required bool timed}) async {
    setState(() => _activeMockLoading = true);
    final testId = testSummary['id'] as String? ?? testSummary['firestoreId'] as String?;
    if (testId == null) {
      setState(() => _activeMockLoading = false);
      return;
    }
    final fullTest = await MockTestService.getMockTestWithQuestions(_selectedExam, testId);
    if (!mounted) return;

    if (fullTest == null || (fullTest['questions'] as List?)?.isEmpty == true) {
      setState(() => _activeMockLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not load this test. Please try again.', style: GoogleFonts.poppins(fontSize: 12)),
        backgroundColor: const Color(0xFFEF4444),
      ));
      return;
    }

    setState(() {
      _activeMock = fullTest;
      _mockIndex = 0; _mockScore = 0;
      _mockAns = null; _mockShowExp = false; _mockDone = false;
      _timedMode = timed; _mockAnswers = {};
      _activeMockLoading = false;
    });

    if (timed) {
      _startTimer(fullTest['duration'] as int? ?? 1200);
    }
  }

  void _startTimer(int seconds) {
    _timeLeft = seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timeLeft <= 0) { t.cancel(); setState(() => _mockDone = true); }
      else setState(() => _timeLeft--);
    });
  }

  String _fmt(int s) => '${(s~/60).toString().padLeft(2,'0')}:${(s%60).toString().padLeft(2,'0')}';

  Color _diffColor(String d) {
    if (d.contains('Easy')) return const Color(0xFF10B981);
    if (d.contains('Hard')) return const Color(0xFFEF4444);
    return const Color(0xFFF59E0B);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(children: [
        _header(),
        _examSelector(),
        _tabBar(),
        Expanded(child: TabBarView(controller: _tabController, children: [
          _notesTab(), _pyqTab(), _mockTab(), _qrTab(), _resourcesTab(),
        ])),
      ]),
      bottomNavigationBar: _bottomNav(),
    );
  }

  Widget _header() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF1976D2)]),
    ),
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16, right: 16, bottom: 16,
    ),
    child: Row(children: [
      GestureDetector(onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back, color: Colors.white)),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Study Material', style: GoogleFonts.poppins(
            color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
        Text(StudyData.getExamPattern(_selectedExam),
            style: GoogleFonts.poppins(color: Colors.white60, fontSize: 10),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    ]),
  );

  Widget _examSelector() => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: SizedBox(height: 34,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _exams.length,
        itemBuilder: (_, i) {
          final e = _exams[i]; final sel = _selectedExam == e;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedExam = e; _resetQuiz(); _resetMock();
              });
              _loadMockTests();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: sel ? const Color(0xFF1565C0) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? const Color(0xFF1565C0) : Colors.grey.shade300),
              ),
              child: Text(e, style: GoogleFonts.poppins(
                  fontSize: 11, fontWeight: FontWeight.w500,
                  color: sel ? Colors.white : Colors.grey.shade600)),
            ),
          );
        },
      ),
    ),
  );

  Widget _tabBar() => Container(
    color: Colors.white,
    child: TabBar(
      controller: _tabController,
      labelColor: const Color(0xFF1565C0),
      unselectedLabelColor: Colors.grey.shade500,
      indicatorColor: const Color(0xFF1565C0),
      indicatorWeight: 3,
      labelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11),
      tabs: const [
        Tab(icon: Icon(Icons.menu_book, size: 16), text: 'Notes'),
        Tab(icon: Icon(Icons.history_edu, size: 16), text: 'PYQ'),
        Tab(icon: Icon(Icons.quiz, size: 16), text: 'Mock Test'),
        Tab(icon: Icon(Icons.flash_on, size: 16), text: 'Quick Rev'),
        Tab(icon: Icon(Icons.link, size: 16), text: 'Resources'),
      ],
    ),
  );

  Widget _notesTab() => ListView(padding: const EdgeInsets.all(16), children: [
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF42A5F5)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        const Icon(Icons.school_rounded, color: Colors.white, size: 28),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$_selectedExam Notes', style: GoogleFonts.poppins(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
          Text('${_sections.fold(0,(s,sec)=>s+(sec['topics'] as List).length)} topics • Exam level content',
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
        ])),
      ]),
    ),
    const SizedBox(height: 14),
    ..._sections.map((sec) {
      final topics = sec['topics'] as List;
      final color = Color(sec['colorHex'] as int);
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 34, height: 34,
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.circle_outlined, color: color, size: 18)),
          const SizedBox(width: 10),
          Expanded(child: Text(sec['title'] as String, style: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E)))),
          Text('${topics.length} topics', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
        ]),
        const SizedBox(height: 8),
        ...topics.map((t) => GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => _TopicScreen(topic: t as Map<String,dynamic>, color: color, section: sec['title'] as String),
          )),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
            ),
            child: Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t['title'] as String, style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A2E))),
                Text('${t['weightage']} • ${t['readTime']}', style: GoogleFonts.poppins(
                    fontSize: 11, color: Colors.grey.shade500)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _diffColor(t['difficulty'] as String).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(t['difficulty'] as String, style: GoogleFonts.poppins(
                    fontSize: 10, fontWeight: FontWeight.w600,
                    color: _diffColor(t['difficulty'] as String))),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 18),
            ]),
          ),
        )),
        const SizedBox(height: 8),
      ]);
    }),
  ]);

  Widget _pyqTab() {
    if (!_quizStarted) return _quizStart();
    if (_quizIndex >= _pyqs.length) return _result(false);
    return _question(_pyqs[_quizIndex], false);
  }

  Widget _quizStart() => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(width: 90, height: 90,
          decoration: BoxDecoration(color: const Color(0xFF1565C0).withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.history_edu_rounded, size: 44, color: Color(0xFF1565C0))),
      const SizedBox(height: 20),
      Text('Previous Year Questions', style: GoogleFonts.poppins(
          fontSize: 19, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E))),
      const SizedBox(height: 6),
      Text('${_pyqs.length} questions • $_selectedExam • With explanations',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
      const SizedBox(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _badge('${_pyqs.length}', 'Questions'),
        const SizedBox(width: 12),
        _badge('2024', 'Latest'),
      ]),
      const SizedBox(height: 28),
      SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: () => setState(() { _quizStarted = true; _quizIndex = 0; _score = 0; _selAns = null; _showExp = false; }),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1565C0),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text('Start Practice', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      )),
    ],
  )));

  Widget _badge(String v, String l) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(color: const Color(0xFF1565C0).withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
    child: Column(children: [
      Text(v, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF1565C0))),
      Text(l, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
    ]),
  );

  Widget _question(Map<String,dynamic> q, bool isMock) {
    final opts    = q['opts'] as List;
    final correct = q['ans'] as int;
    final selAns  = isMock ? _mockAns : _selAns;
    final showExp = isMock ? _mockShowExp : _showExp;
    final idx     = isMock ? _mockIndex : _quizIndex;
    final total   = isMock ? (_activeMock!['questions'] as List).length : _pyqs.length;
    final score   = isMock ? _mockScore : _score;

    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMock && _timedMode)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _timeLeft < 60 ? const Color(0xFFEF4444).withOpacity(0.1) : const Color(0xFF1565C0).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Icon(Icons.timer, size: 18, color: _timeLeft < 60 ? const Color(0xFFEF4444) : const Color(0xFF1565C0)),
              const SizedBox(width: 6),
              Text(_fmt(_timeLeft), style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w700,
                  color: _timeLeft < 60 ? const Color(0xFFEF4444) : const Color(0xFF1565C0))),
            ]),
          ),
        Row(children: [
          Text('Q ${idx+1}/$total', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1565C0))),
          const SizedBox(width: 10),
          Expanded(child: LinearProgressIndicator(
            value: (idx+1)/total,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation(Color(0xFF1565C0)),
            borderRadius: BorderRadius.circular(4), minHeight: 5,
          )),
          const SizedBox(width: 10),
          Text('Score: $score', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF10B981))),
        ]),
        const SizedBox(height: 10),
        if (q.containsKey('subject')) Row(children: [
          _tag(q['subject'] as String, const Color(0xFF1565C0)),
          if (q.containsKey('year')) ...[const SizedBox(width: 6), _tag('${q['year']}', const Color(0xFF10B981))],
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
          ),
          child: Text(q['q'] as String, style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A2E), height: 1.5)),
        ),
        const SizedBox(height: 12),
        // ── OPTIONS — Fixed answer highlighting ──
        ...opts.asMap().entries.map((e) {
          final i   = e.key;
          final opt = e.value as String;
          final lbl = ['A','B','C','D'][i];

          // Default colors
          Color bg     = Colors.white;
          Color border = Colors.grey.shade200;
          Color txt    = const Color(0xFF374151);
          Color lblBg  = const Color(0xFF1565C0);
          IconData? trailingIcon;
          Color? trailingColor;

          if (selAns != null) {
            // Always make correct answer GREEN
            if (i == correct) {
              bg     = const Color(0xFF10B981).withOpacity(0.1);
              border = const Color(0xFF10B981);
              txt    = const Color(0xFF10B981);
              lblBg  = const Color(0xFF10B981);
              trailingIcon  = Icons.check_circle;
              trailingColor = const Color(0xFF10B981);
            }
            // If user selected wrong answer — make it RED
            else if (selAns == lbl && i != correct) {
              bg     = const Color(0xFFEF4444).withOpacity(0.1);
              border = const Color(0xFFEF4444);
              txt    = const Color(0xFFEF4444);
              lblBg  = const Color(0xFFEF4444);
              trailingIcon  = Icons.cancel;
              trailingColor = const Color(0xFFEF4444);
            }
          }

          return GestureDetector(
            onTap: selAns == null ? () {
              final isCorrect = i == correct;

              if (isMock) {
                setState(() {
                  _mockAns      = lbl;
                  _mockShowExp  = true;
                  if (isCorrect) _mockScore++;
                  _mockAnswers[_mockIndex] = isCorrect;
                });
              } else {
                setState(() {
                  _selAns  = lbl;
                  _showExp = true;
                  if (isCorrect) _score++;
                });
              }

              // Memory Box: automatically save wrong answers from BOTH
              // daily PYQ practice and mock tests. Safe no-op if the
              // user isn't logged in (handled inside the service).
              if (!isCorrect) {
                final qId = '${_selectedExam}_${q['subject'] ?? 'General'}_${q['id']}';
                MemoryBoxService.saveWrongAnswer(
                  questionId: qId,
                  question: q['q'] as String,
                  options: (q['opts'] as List).cast<String>(),
                  correctIndex: correct,
                  explanation: q['exp'] as String? ?? '',
                  topic: q['subject'] as String? ?? q['topic'] as String? ?? 'General',
                  exam: _selectedExam,
                );
              }
            } : null,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: border),
              ),
              child: Row(children: [
                Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(color: lblBg, borderRadius: BorderRadius.circular(7)),
                  child: Center(child: Text(lbl, style: GoogleFonts.poppins(
                      fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white))),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(opt, style: GoogleFonts.poppins(
                    fontSize: 13, color: txt,
                    fontWeight: selAns != null && i == correct ? FontWeight.w600 : FontWeight.w400))),
                if (trailingIcon != null)
                  Icon(trailingIcon, color: trailingColor, size: 18),
              ]),
            ),
          );
        }),
        if (showExp) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.2)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.lightbulb_outline, color: Color(0xFF1565C0), size: 15),
                const SizedBox(width: 5),
                Text('Explanation', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1565C0))),
              ]),
              const SizedBox(height: 4),
              Text(q['exp'] as String, style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF374151), height: 1.4)),
            ]),
          ),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () {
              if (isMock) {
                final qList = _activeMock!['questions'] as List;
                setState(() {
                  if (_mockIndex < qList.length - 1) {
                    _mockIndex++; _mockAns = null; _mockShowExp = false;
                  } else {
                    _mockDone = true; _timer?.cancel();
                  }
                });
              } else {
                setState(() {
                  if (_quizIndex < _pyqs.length - 1) {
                    _quizIndex++; _selAns = null; _showExp = false;
                  } else {
                    _quizIndex = _pyqs.length;
                  }
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              isMock
                  ? (_mockIndex < (_activeMock!['questions'] as List).length - 1 ? 'Next Question →' : 'See Results')
                  : (_quizIndex < _pyqs.length - 1 ? 'Next Question →' : 'See Results'),
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          )),
        ],
      ],
    ));
  }

  Widget _tag(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
    child: Text(t, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: c)),
  );

  // ── MOCK TEST ANALYSER RESULT ──────────────────────────────
  Widget _result(bool isMock) {
    final questions = isMock
        ? (_activeMock!['questions'] as List).cast<Map<String,dynamic>>()
        : _pyqs;
    final total = questions.length;
    final s     = isMock ? _mockScore : _score;
    final pct   = total > 0 ? (s / total * 100).round() : 0;
    final c     = pct >= 70 ? const Color(0xFF10B981) : pct >= 50 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);
    final msg   = pct >= 70 ? 'Excellent! 🎉' : pct >= 50 ? 'Good Effort! 👍' : 'Keep Practicing! 💪';

    // Build topic analysis from tracked answers
    final Map<String, int> topicCorrect = {};
    final Map<String, int> topicTotal   = {};
    if (isMock) {
      for (int i = 0; i < questions.length; i++) {
        final subject = questions[i]['subject'] as String? ?? 'General';
        topicTotal[subject]   = (topicTotal[subject] ?? 0) + 1;
        topicCorrect[subject] = (topicCorrect[subject] ?? 0) + (_mockAnswers[i] == true ? 1 : 0);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        // Score circle
        Container(
          width: 120, height: 120,
          decoration: BoxDecoration(
            color: c.withOpacity(0.1), shape: BoxShape.circle,
            border: Border.all(color: c, width: 3),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$pct%', style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w800, color: c)),
            Text('$s/$total', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
          ]),
        ),
        const SizedBox(height: 12),
        Text(msg, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: c)),
        const SizedBox(height: 4),
        Text('$s out of $total correct', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade500)),
        const SizedBox(height: 20),

        // Performance banner
        Container(
          width: double.infinity, padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.withOpacity(0.3)),
          ),
          child: Row(children: [
            Icon(pct >= 70 ? Icons.emoji_events_rounded : pct >= 50 ? Icons.thumb_up_rounded : Icons.trending_up_rounded, color: c, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  pct >= 70 ? 'Outstanding Performance!' : pct >= 50 ? 'You are on the right track!' : "Don't give up — practice more!",
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: c)),
              Text(
                  pct >= 70 ? 'You are exam ready. Keep this pace!' : pct >= 50 ? 'Focus on weak areas to score 70%+' : 'Revise notes and attempt again',
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600)),
            ])),
          ]),
        ),
        const SizedBox(height: 20),

        // Topic-wise analysis
        if (isMock && topicTotal.isNotEmpty) ...[
          Align(alignment: Alignment.centerLeft,
              child: Text('📊 Topic-wise Analysis', style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E)))),
          const SizedBox(height: 10),
          ...topicTotal.entries.map((entry) {
            final subject  = entry.key;
            final tTotal   = entry.value;
            final tCorrect = topicCorrect[subject] ?? 0;
            final tPct     = tTotal > 0 ? (tCorrect / tTotal * 100).round() : 0;
            final tColor   = tPct >= 70 ? const Color(0xFF10B981) : tPct >= 50 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);
            final label    = tPct >= 70 ? '✅ Strong' : tPct >= 50 ? '⚠️ Average' : '❌ Weak';
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(subject, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A2E))),
                  Row(children: [
                    Text('$tCorrect/$tTotal', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: tColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: Text(label, style: GoogleFonts.poppins(fontSize: 10, color: tColor, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ]),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: tPct / 100,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(tColor),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 4),
                Text('$tPct% accuracy', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
              ]),
            );
          }),
          const SizedBox(height: 20),

          // Recommendations
          Align(alignment: Alignment.centerLeft,
              child: Text('💡 Recommendations', style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E)))),
          const SizedBox(height: 10),
          ...topicTotal.entries.where((e) {
            final tPct = e.value > 0 ? ((topicCorrect[e.key] ?? 0) / e.value * 100).round() : 0;
            return tPct < 70;
          }).map((entry) {
            final tPct = entry.value > 0 ? ((topicCorrect[entry.key] ?? 0) / entry.value * 100).round() : 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E7), borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('💡 ', style: TextStyle(fontSize: 16)),
                Expanded(child: Text(_getTip(entry.key, tPct),
                    style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF374151)))),
              ]),
            );
          }),
          const SizedBox(height: 20),
        ],

        // Buttons
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () => isMock ? _resetMock() : _resetQuiz(),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text('Try Again', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        )),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: OutlinedButton(
          onPressed: () => isMock ? _resetMock() : _resetQuiz(),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: Color(0xFF1565C0)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text('Back to Tests', style: GoogleFonts.poppins(
              color: const Color(0xFF1565C0), fontWeight: FontWeight.w600)),
        )),
        const SizedBox(height: 20),
      ]),
    );
  }

  String _getTip(String subject, int pct) {
    switch (subject) {
      case 'Reasoning': return 'Reasoning: Practice Puzzles, Series, and Blood Relations daily. Aim for 20-25 correct in SSC CGL. Use Study Notes for shortcut tricks.';
      case 'Maths': return 'Maths: Focus on Percentage, Profit-Loss, and Time & Work. These 3 topics cover 40% of Maths questions. Practice 20 questions daily.';
      case 'English': return 'English: Read 1 editorial daily. Focus on Error Detection and Reading Comprehension. Learn 10 new words every day.';
      case 'GK': case 'General Knowledge': return 'GK: Read daily current affairs for 15 mins. Focus on History, Geography, Polity. Revise Quick Revision cards.';
      case 'General Science': case 'Science': return 'Science: Focus on Biology (Cell, Human Body) and Physics basics. NCERT 8th-10th covers 80% of exam questions.';
      case 'Banking': return 'Banking: Read RBI news, current bank rates (Repo, CRR, SLR). Focus on recent banking schemes.';
      default: return '$subject: Revise the study notes and attempt more practice questions. Current accuracy: $pct% — aim for 70%+.';
    }
  }

  Widget _mockTab() {
    // Currently inside an active test
    if (_activeMock != null) {
      if (_mockDone) return _result(true);
      final qList = _activeMock!['questions'] as List;
      return _question(qList[_mockIndex] as Map<String,dynamic>, true);
    }

    // Fetching the full test (with questions) after tapping Practice/Timed
    if (_activeMockLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0)));
    }

    // Loading the list of available tests for this exam
    if (_mocksLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0)));
    }

    // Failed to load list
    if (_mockLoadError) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text('Could not load mock tests', style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
          const SizedBox(height: 6),
          Text('Check your internet connection and try again.', textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadMockTests,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0)),
            child: Text('Retry', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ]),
      ));
    }

    // No tests yet for this exam
    if (_mocks.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.quiz_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text('No mock tests yet for $_selectedExam', textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
          const SizedBox(height: 6),
          Text('We\'re adding more tests soon — check back later!', textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
        ]),
      ));
    }

    return ListView(padding: const EdgeInsets.all(16), children: [
      ..._mocks.map((mt) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
        ),
        child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(width: 44, height: 44,
                  decoration: BoxDecoration(color: const Color(0xFF1565C0).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.quiz_outlined, color: Color(0xFF1565C0), size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(mt['title'] as String? ?? 'Mock Test', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E))),
                Text(mt['description'] as String? ?? '', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
              ])),
            ]),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () => _startMockTest(mt, timed: false),
                icon: const Icon(Icons.psychology_outlined, size: 15),
                label: Text('Practice', style: GoogleFonts.poppins(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1565C0),
                  side: const BorderSide(color: Color(0xFF1565C0)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(
                onPressed: () => _startMockTest(mt, timed: true),
                icon: const Icon(Icons.timer_outlined, size: 15, color: Colors.white),
                label: Text('Timed (${_fmt(mt['duration'] as int? ?? 1200)})', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              )),
            ]),
          ],
        )),
      )),
    ]);
  }

  Widget _qrTab() => ListView(padding: const EdgeInsets.all(16), children: [
    ..._qr.map((sec) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(sec['title'] as String, style: GoogleFonts.poppins(
          fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E))),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
        ),
        child: Column(children: (sec['items'] as List).asMap().entries.map((e) {
          final isLast = e.key == (sec['items'] as List).length - 1;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 22, height: 22,
                    decoration: BoxDecoration(color: const Color(0xFF1565C0).withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                    child: Center(child: Text('${e.key+1}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1565C0))))),
                const SizedBox(width: 10),
                Expanded(child: Text(e.value as String, style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF374151), height: 1.4))),
              ]),
            ),
            if (!isLast) Divider(height: 1, color: Colors.grey.shade100),
          ]);
        }).toList()),
      ),
      const SizedBox(height: 16),
    ])),
  ]);

  Widget _bottomNav() => BottomNavigationBar(
    currentIndex: 0,
    type: BottomNavigationBarType.fixed,
    selectedItemColor: const Color(0xFF1565C0),
    unselectedItemColor: Colors.grey.shade400,
    selectedLabelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
    unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11),
    onTap: (i) {
      switch(i) {
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

  // ── FREE RESOURCES DATA (OFFICIAL SITES ONLY) ───────────────
  static const Map<String, List<Map<String, dynamic>>> _resources = {
    'SSC CGL': [
      {'category': 'Official Exam Website', 'icon': 'official', 'color': 0xFF1565C0, 'items': [
        {'title': 'SSC Official Website', 'subtitle': 'Notifications, syllabus, admit cards, results', 'url': 'https://ssc.gov.in'},
        {'title': 'SSC Previous Year Papers', 'subtitle': 'Download official CGL question papers free', 'url': 'https://ssc.gov.in/candidate-corner/question-papers'},
      ]},
      {'category': 'Free Books & Notes', 'icon': 'book', 'color': 0xFF10B981, 'items': [
        {'title': 'NCERT Textbooks (Free PDF)', 'subtitle': 'Class 6-12 all subjects — official NCERT site', 'url': 'https://ncert.nic.in/textbook.php'},
        {'title': 'PIB Current Affairs', 'subtitle': 'Official Govt of India press releases for GK', 'url': 'https://pib.gov.in'},
      ]},
    ],
    'SSC CHSL': [
      {'category': 'Official Exam Website', 'icon': 'official', 'color': 0xFF1565C0, 'items': [
        {'title': 'SSC Official Website', 'subtitle': 'CHSL notifications, syllabus, results', 'url': 'https://ssc.gov.in'},
        {'title': 'SSC Previous Year Papers', 'subtitle': 'Download official CHSL question papers free', 'url': 'https://ssc.gov.in/candidate-corner/question-papers'},
      ]},
      {'category': 'Free Books & Notes', 'icon': 'book', 'color': 0xFF10B981, 'items': [
        {'title': 'NCERT Textbooks (Free PDF)', 'subtitle': 'Class 6-12 all subjects — official NCERT site', 'url': 'https://ncert.nic.in/textbook.php'},
        {'title': 'PIB Current Affairs', 'subtitle': 'Official Govt of India press releases for GK', 'url': 'https://pib.gov.in'},
      ]},
    ],
    'RRB NTPC': [
      {'category': 'Official Exam Website', 'icon': 'official', 'color': 0xFF1565C0, 'items': [
        {'title': 'Indian Railways Official', 'subtitle': 'RRB NTPC notifications and recruitment', 'url': 'https://indianrailways.gov.in'},
        {'title': 'RRB Chandigarh (North India)', 'subtitle': 'Official RRB for Punjab, Haryana, HP candidates', 'url': 'https://www.rrbcdg.gov.in'},
        {'title': 'RRB Apply Portal', 'subtitle': 'All RRB zone notifications and applications', 'url': 'https://www.rrbapply.gov.in'},
      ]},
      {'category': 'Free Books & Notes', 'icon': 'book', 'color': 0xFF10B981, 'items': [
        {'title': 'NCERT Textbooks (Free PDF)', 'subtitle': 'Maths, Science, GK — Class 6-12 official', 'url': 'https://ncert.nic.in/textbook.php'},
        {'title': 'PIB Current Affairs', 'subtitle': 'Official Govt news for Railway GA section', 'url': 'https://pib.gov.in'},
      ]},
    ],
    'Army Agniveer': [
      {'category': 'Official Exam Website', 'icon': 'official', 'color': 0xFF1565C0, 'items': [
        {'title': 'Join Indian Army Official', 'subtitle': 'Agniveer Army notifications and syllabus', 'url': 'https://joinindianarmy.nic.in'},
        {'title': 'Agniveervayu (Air Force)', 'subtitle': 'Official Air Force Agniveer portal', 'url': 'https://agnipathvayu.cdac.in'},
        {'title': 'Join Indian Navy Official', 'subtitle': 'Navy Agniveer SSR/MR notifications', 'url': 'https://www.joinindiannavy.gov.in'},
      ]},
      {'category': 'Free Books & Notes', 'icon': 'book', 'color': 0xFF10B981, 'items': [
        {'title': 'NCERT Textbooks (Free PDF)', 'subtitle': 'Class 10-12 Maths, Science, English official', 'url': 'https://ncert.nic.in/textbook.php'},
        {'title': 'PIB Current Affairs', 'subtitle': 'Official Govt news for GK section', 'url': 'https://pib.gov.in'},
      ]},
    ],
    'Punjab Police': [
      {'category': 'Official Exam Website', 'icon': 'official', 'color': 0xFF1565C0, 'items': [
        {'title': 'Punjab Police Official', 'subtitle': 'Constable notifications, results, recruitment', 'url': 'https://punjabpolice.gov.in'},
        {'title': 'PPSC Official Website', 'subtitle': 'Punjab Public Service Commission portal', 'url': 'https://ppsc.gov.in'},
        {'title': 'Punjab Govt Portal', 'subtitle': 'All Punjab government recruitment notifications', 'url': 'https://punjab.gov.in'},
      ]},
      {'category': 'Free Books & Notes', 'icon': 'book', 'color': 0xFF10B981, 'items': [
        {'title': 'NCERT Textbooks (Free PDF)', 'subtitle': 'Class 10-12 Hindi, English, GK official', 'url': 'https://ncert.nic.in/textbook.php'},
        {'title': 'PIB Current Affairs', 'subtitle': 'Official Govt news for current affairs section', 'url': 'https://pib.gov.in'},
      ]},
    ],
    'IBPS PO': [
      {'category': 'Official Exam Website', 'icon': 'official', 'color': 0xFF1565C0, 'items': [
        {'title': 'IBPS Official Website', 'subtitle': 'PO, Clerk, SO — official notifications and results', 'url': 'https://www.ibps.in'},
        {'title': 'SBI Careers Official', 'subtitle': 'SBI PO and Clerk official notifications', 'url': 'https://www.sbi.co.in/web/careers'},
        {'title': 'RBI Official Website', 'subtitle': 'Banking awareness — official RBI site', 'url': 'https://www.rbi.org.in'},
      ]},
      {'category': 'Free Books & Notes', 'icon': 'book', 'color': 0xFF10B981, 'items': [
        {'title': 'NCERT Class 11-12 Economics', 'subtitle': 'Best source for banking economy concepts', 'url': 'https://ncert.nic.in/textbook.php'},
        {'title': 'PIB Current Affairs', 'subtitle': 'Economy and banking news — official source', 'url': 'https://pib.gov.in'},
        {'title': 'RBI Publications', 'subtitle': 'Annual reports, monetary policy — official RBI', 'url': 'https://www.rbi.org.in/scripts/publications.aspx'},
      ]},
    ],
    'UPSC CSE': [
      {'category': 'Official Exam Website', 'icon': 'official', 'color': 0xFF1565C0, 'items': [
        {'title': 'UPSC Official Website', 'subtitle': 'CSE notifications, syllabus, results', 'url': 'https://upsc.gov.in'},
        {'title': 'UPSC Previous Year Papers', 'subtitle': 'Official Prelims and Mains PYQs — free', 'url': 'https://upsc.gov.in/examinations/previous-question-papers'},
        {'title': 'UPSC Online Application', 'subtitle': 'Apply for UPSC exams — official portal', 'url': 'https://upsconline.nic.in'},
      ]},
      {'category': 'Free Books & Notes', 'icon': 'book', 'color': 0xFF10B981, 'items': [
        {'title': 'NCERT Textbooks (Free PDF)', 'subtitle': 'Class 6-12 — backbone of UPSC preparation', 'url': 'https://ncert.nic.in/textbook.php'},
        {'title': 'PIB Current Affairs', 'subtitle': 'Must-read official source for UPSC current affairs', 'url': 'https://pib.gov.in'},
        {'title': 'Economic Survey (Official)', 'subtitle': 'Ministry of Finance — official economic data', 'url': 'https://www.indiabudget.gov.in/economicsurvey'},
        {'title': 'India Year Book (Official)', 'subtitle': 'Official Govt of India yearbook — free online', 'url': 'https://publications.india.gov.in'},
      ]},
    ],
    'Delhi Police': [
      {'category': 'Official Exam Website', 'icon': 'official', 'color': 0xFF1565C0, 'items': [
        {'title': 'Delhi Police Official', 'subtitle': 'Constable and Head Constable recruitment', 'url': 'https://www.delhipolice.gov.in'},
        {'title': 'SSC Official Website', 'subtitle': 'Delhi Police SI/Inspector via SSC CPO', 'url': 'https://ssc.gov.in'},
        {'title': 'SSC Previous Year Papers', 'subtitle': 'Official Delhi Police CPO question papers', 'url': 'https://ssc.gov.in/candidate-corner/question-papers'},
      ]},
      {'category': 'Free Books & Notes', 'icon': 'book', 'color': 0xFF10B981, 'items': [
        {'title': 'NCERT Textbooks (Free PDF)', 'subtitle': 'Class 10-12 GK, English, Science official', 'url': 'https://ncert.nic.in/textbook.php'},
        {'title': 'PIB Current Affairs', 'subtitle': 'Official Govt news for Delhi Police GK', 'url': 'https://pib.gov.in'},
      ]},
    ],
    'Haryana Police': [
      {'category': 'Official Exam Website', 'icon': 'official', 'color': 0xFF1565C0, 'items': [
        {'title': 'Haryana Police Official', 'subtitle': 'Constable recruitment notifications and syllabus', 'url': 'https://haryanapoliceonline.gov.in'},
        {'title': 'HSSC Official Website', 'subtitle': 'Haryana Staff Selection Commission portal', 'url': 'https://hssc.gov.in'},
        {'title': 'Haryana Govt Portal', 'subtitle': 'All Haryana government recruitment info', 'url': 'https://haryana.gov.in'},
      ]},
      {'category': 'Free Books & Notes', 'icon': 'book', 'color': 0xFF10B981, 'items': [
        {'title': 'NCERT Textbooks (Free PDF)', 'subtitle': 'Class 10-12 Hindi, Maths, GK — official NCERT', 'url': 'https://ncert.nic.in/textbook.php'},
        {'title': 'PIB Current Affairs', 'subtitle': 'National and state current affairs — official', 'url': 'https://pib.gov.in'},
      ]},
    ],
    'NDA': [
      {'category': 'Official Exam Website', 'icon': 'official', 'color': 0xFF1565C0, 'items': [
        {'title': 'UPSC NDA Official', 'subtitle': 'NDA notification, syllabus, admit card, results', 'url': 'https://upsc.gov.in'},
        {'title': 'NDA Previous Year Papers', 'subtitle': 'Official UPSC NDA PYQs — free download', 'url': 'https://upsc.gov.in/examinations/previous-question-papers'},
        {'title': 'Join Indian Army Official', 'subtitle': 'NDA career and training information', 'url': 'https://joinindianarmy.nic.in'},
        {'title': 'UPSC Online Application', 'subtitle': 'Apply for NDA exam — official UPSC portal', 'url': 'https://upsconline.nic.in'},
      ]},
      {'category': 'Free Books & Notes', 'icon': 'book', 'color': 0xFF10B981, 'items': [
        {'title': 'NCERT Class 11-12 Maths', 'subtitle': 'Essential for NDA Maths paper — official NCERT', 'url': 'https://ncert.nic.in/textbook.php'},
        {'title': 'NCERT Class 11-12 Physics', 'subtitle': 'NDA GAT Science section — official NCERT', 'url': 'https://ncert.nic.in/textbook.php'},
        {'title': 'PIB Current Affairs', 'subtitle': 'Official Govt news for NDA GAT section', 'url': 'https://pib.gov.in'},
      ]},
    ],
  };

  // ── RESOURCES TAB ────────────────────────────────────────────
  Widget _resourcesTab() {
    final examResources = _resources[_selectedExam] ?? _resources['SSC CGL']!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF6A1B9A), Color(0xFF9C27B0)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Free Resources — $_selectedExam',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              Text('Official government websites only',
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
            ])),
          ]),
        ),
        const SizedBox(height: 16),
        ...examResources.map((category) {
          final items = category['items'] as List<dynamic>;
          final catIcon = category['icon'] as String;
          final Color catColor = Color(category['color'] as int);
          final IconData catIconData = catIcon == 'official' ? Icons.language : Icons.menu_book;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: catColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(catIconData, color: catColor, size: 16),
              ),
              const SizedBox(width: 8),
              Text(category['category'] as String,
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E))),
            ]),
            const SizedBox(height: 8),
            ...items.map((item) {
              final m = item as Map<String, dynamic>;
              return GestureDetector(
                onTap: () => _launchUrl(m['url'] as String),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
                  ),
                  child: Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: catColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: Icon(catIconData, color: catColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m['title'] as String,
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A2E))),
                      Text(m['subtitle'] as String,
                          style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
                    ])),
                    Icon(Icons.arrow_forward_ios, size: 12, color: catColor),
                  ]),
                ),
              );
            }),
            const SizedBox(height: 12),
          ]);
        }),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFC107).withOpacity(0.5)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'All links open official government websites only. Internet connection required.',
              style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF92400E)),
            )),
          ]),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  void _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Opening: $url', style: GoogleFonts.poppins(fontSize: 12)),
          backgroundColor: const Color(0xFF1565C0),
          duration: const Duration(seconds: 2),
        ));
      }
    }
  }

}
class _TopicScreen extends StatelessWidget {
  final Map<String,dynamic> topic;
  final Color color;
  final String section;
  const _TopicScreen({required this.topic, required this.color, required this.section});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: color, foregroundColor: Colors.white, elevation: 0,
        title: Text(topic['title'] as String, style: GoogleFonts.poppins(
            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
        actions: [
          Padding(padding: const EdgeInsets.only(right: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: Text(topic['difficulty'] as String, style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              )),
        ],
      ),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _chip(Icons.bar_chart, '${topic['weightage']}', color),
            const SizedBox(width: 8),
            _chip(Icons.timer_outlined, topic['readTime'] as String, color),
          ]),
          const SizedBox(height: 14),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
            ),
            child: SelectableText(topic['content'] as String, style: GoogleFonts.poppins(
                fontSize: 13, color: const Color(0xFF374151), height: 1.7)),
          ),
        ],
      )),
    );
  }

  Widget _chip(IconData icon, String label, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: c),
      const SizedBox(width: 5),
      Text(label, style: GoogleFonts.poppins(fontSize: 11, color: c, fontWeight: FontWeight.w600)),
    ]),
  );
}