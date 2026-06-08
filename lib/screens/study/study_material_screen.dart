import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:examtrack/screens/study/study_data.dart';

class StudyMaterialScreen extends StatefulWidget {
  const StudyMaterialScreen({super.key});
  @override
  State<StudyMaterialScreen> createState() => _StudyMaterialScreenState();
}

class _StudyMaterialScreenState extends State<StudyMaterialScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedExam = 'SSC CGL';
  final List<String> _exams = ['SSC CGL','RRB NTPC','Army Agniveer','Punjab Police','IBPS PO'];

  // PYQ state
  int _quizIndex = 0;
  String? _selAns;
  bool _showExp = false;
  int _score = 0;
  bool _quizStarted = false;

  // Mock test state
  Map<String,dynamic>? _activeMock;
  int _mockIndex = 0;
  String? _mockAns;
  bool _mockShowExp = false;
  int _mockScore = 0;
  bool _mockDone = false;
  Timer? _timer;
  int _timeLeft = 0;
  bool _timedMode = false;

  List<Map<String,dynamic>> get _sections => StudyData.getSections(_selectedExam);
  List<Map<String,dynamic>> get _pyqs => StudyData.getPYQs(_selectedExam);
  List<Map<String,dynamic>> get _mocks => StudyData.getMocks(_selectedExam);
  List<Map<String,dynamic>> get _qr => StudyData.getQR(_selectedExam);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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

  void _resetMock() {
    _timer?.cancel();
    setState(() {
      _activeMock = null; _mockIndex = 0; _mockScore = 0;
      _mockAns = null; _mockShowExp = false; _mockDone = false;
    });
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
          _notesTab(), _pyqTab(), _mockTab(), _qrTab(),
        ])),
      ]),
      bottomNavigationBar: _bottomNav(),
    );
  }

  // ── HEADER ────────────────────────────────────────────────
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

  // ── EXAM SELECTOR ─────────────────────────────────────────
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
            onTap: () => setState(() {
              _selectedExam = e; _resetQuiz(); _resetMock();
            }),
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

  // ── TAB BAR ───────────────────────────────────────────────
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
      ],
    ),
  );

  // ── NOTES TAB ─────────────────────────────────────────────
  Widget _notesTab() => ListView(padding: const EdgeInsets.all(16), children: [
    // Banner
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
    // Sections
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

  // ── PYQ TAB ───────────────────────────────────────────────
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
    final opts = q['opts'] as List;
    final correct = q['ans'] as int;
    final selAns = isMock ? _mockAns : _selAns;
    final showExp = isMock ? _mockShowExp : _showExp;
    final idx = isMock ? _mockIndex : _quizIndex;
    final total = isMock ? (_activeMock!['questions'] as List).length : _pyqs.length;
    final score = isMock ? _mockScore : _score;

    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timer for timed mock
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
        // Progress
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
        // Tags
        if (q.containsKey('subject')) Row(children: [
          _tag(q['subject'] as String, const Color(0xFF1565C0)),
          const SizedBox(width: 6),
          if (q.containsKey('topic')) _tag(q['topic'] as String, Colors.grey.shade500),
          if (q.containsKey('year')) ...[const SizedBox(width: 6), _tag('${q['year']}', const Color(0xFF10B981))],
        ]),
        const SizedBox(height: 10),
        // Question box
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
        // Options
        ...opts.asMap().entries.map((e) {
          final i = e.key; final opt = e.value as String;
          final lbl = ['A','B','C','D'][i];
          Color bg = Colors.white, border = Colors.grey.shade200, txt = const Color(0xFF374151), lblBg = const Color(0xFF1565C0);
          if (selAns != null) {
            if (i == correct) { bg = const Color(0xFF10B981).withOpacity(0.1); border = const Color(0xFF10B981); txt = const Color(0xFF10B981); lblBg = const Color(0xFF10B981); }
            else if (selAns == lbl) { bg = const Color(0xFFEF4444).withOpacity(0.1); border = const Color(0xFFEF4444); txt = const Color(0xFFEF4444); lblBg = const Color(0xFFEF4444); }
          }
          return GestureDetector(
            onTap: selAns == null ? () {
              if (isMock) setState(() { _mockAns = lbl; _mockShowExp = true; if (i==correct) _mockScore++; });
              else setState(() { _selAns = lbl; _showExp = true; if (i==correct) _score++; });
            } : null,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: border)),
              child: Row(children: [
                Container(width: 26, height: 26, decoration: BoxDecoration(color: lblBg, borderRadius: BorderRadius.circular(7)),
                    child: Center(child: Text(lbl, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)))),
                const SizedBox(width: 10),
                Expanded(child: Text(opt, style: GoogleFonts.poppins(fontSize: 13, color: txt,
                    fontWeight: selAns != null && i == correct ? FontWeight.w600 : FontWeight.w400))),
                if (selAns != null && (i == correct || selAns == lbl))
                  Icon(i == correct ? Icons.check_circle : Icons.cancel,
                      color: i == correct ? const Color(0xFF10B981) : const Color(0xFFEF4444), size: 18),
              ]),
            ),
          );
        }),
        // Explanation
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
                  if (_mockIndex < qList.length - 1) { _mockIndex++; _mockAns = null; _mockShowExp = false; }
                  else { _mockDone = true; _timer?.cancel(); }
                });
              } else {
                setState(() {
                  if (_quizIndex < _pyqs.length - 1) { _quizIndex++; _selAns = null; _showExp = false; }
                  else { _quizIndex = _pyqs.length; }
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

  Widget _result(bool isMock) {
    final total = isMock ? (_activeMock!['questions'] as List).length : _pyqs.length;
    final s = isMock ? _mockScore : _score;
    final pct = (s/total*100).round();
    final c = pct >= 70 ? const Color(0xFF10B981) : pct >= 50 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);
    final msg = pct >= 70 ? 'Excellent! 🎉' : pct >= 50 ? 'Good Effort!' : 'Keep Practicing!';
    return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 100, height: 100,
          decoration: BoxDecoration(color: c.withOpacity(0.1), shape: BoxShape.circle),
          child: Center(child: Text('$pct%', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w800, color: c)))),
        const SizedBox(height: 14),
        Text(msg, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: c)),
        const SizedBox(height: 6),
        Text('$s out of $total correct', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade500)),
        const SizedBox(height: 28),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () => isMock ? _resetMock() : _resetQuiz(),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text('Try Again', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        )),
      ],
    )));
  }

  // ── MOCK TEST TAB ─────────────────────────────────────────
  Widget _mockTab() {
    if (_activeMock != null) {
      if (_mockDone) return _result(true);
      final qList = _activeMock!['questions'] as List;
      return _question(qList[_mockIndex] as Map<String,dynamic>, true);
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
                Text(mt['title'] as String, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E))),
                Text(mt['description'] as String, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
              ])),
            ]),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () => setState(() {
                  _activeMock = mt; _mockIndex = 0; _mockScore = 0;
                  _mockAns = null; _mockShowExp = false; _mockDone = false; _timedMode = false;
                }),
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
                onPressed: () => setState(() {
                  _activeMock = mt; _mockIndex = 0; _mockScore = 0;
                  _mockAns = null; _mockShowExp = false; _mockDone = false;
                  _timedMode = true; _startTimer(mt['duration'] as int);
                }),
                icon: const Icon(Icons.timer_outlined, size: 15, color: Colors.white),
                label: Text('Timed (${_fmt(mt['duration'] as int)})', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white)),
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

  // ── QUICK REVISION TAB ────────────────────────────────────
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

  // ── BOTTOM NAV ────────────────────────────────────────────
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
}

// ── Topic Detail Screen ───────────────────────────────────────
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
