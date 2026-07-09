import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:examtrack/screens/study/study_data.dart';
import 'package:examtrack/services/memory_box_service.dart';
import 'package:examtrack/services/mock_test_service.dart';
import 'package:examtrack/services/progress_service.dart';
import 'package:examtrack/widgets/progress_widgets.dart';
import 'package:examtrack/l10n/language_provider.dart';
import 'package:examtrack/l10n/app_strings.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:examtrack/services/study_material_service.dart';
import 'package:examtrack/screens/study/mock_test_screen.dart';

class StudyMaterialScreen extends StatefulWidget {
  final String? initialExam;
  final int initialTabIndex;

  const StudyMaterialScreen({
    super.key,
    this.initialExam,
    this.initialTabIndex = 0,
  });

  @override
  State<StudyMaterialScreen> createState() => _StudyMaterialScreenState();
}

class _StudyMaterialScreenState extends State<StudyMaterialScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String _selectedExam;
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

  // Firestore-backed sections state (Notes tab)
  List<Map<String,dynamic>> _firestoreSections = [];
  bool _sectionsLoading = true;
  bool _sectionsLoadError = false;

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

  List<Map<String,dynamic>> get _sections {
    // Firestore is the source of truth once content has been uploaded
    // for this exam. If nothing has been uploaded yet (empty result),
    // fall back to the local StudyData so the exam never shows a blank
    // "coming soon" screen just because Firestore hasn't been
    // populated yet. This is what lets you add Firestore content for
    // any exam, at any time, without needing a rebuild — the app
    // always has *something* to show either way.
    if (StudyMaterialService.isFirestoreBacked(_selectedExam) &&
        _firestoreSections.isNotEmpty) {
      return _firestoreSections;
    }
    return StudyData.getSections(_selectedExam);
  }
  List<Map<String,dynamic>> get _pyqs => StudyData.getPYQs(_selectedExam);
  List<Map<String,dynamic>> get _mocks => _firestoreMocks;
  List<Map<String,dynamic>> get _qr => StudyData.getQR(_selectedExam);

  @override
  void initState() {
    super.initState();
    _selectedExam = (widget.initialExam != null && _exams.contains(widget.initialExam))
        ? widget.initialExam!
        : _exams[0];
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _loadMockTests();
    _loadSections();
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

  Future<void> _loadMockTests() async {
    if (!mounted) return;
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

  Future<void> _loadSections() async {
    if (!StudyMaterialService.isFirestoreBacked(_selectedExam)) {
      // Not Firestore-backed — local StudyData is used directly via
      // the _sections getter, no async loading needed.
      if (!mounted) return;
      setState(() {
        _sectionsLoading = false;
        _sectionsLoadError = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _sectionsLoading = true;
      _sectionsLoadError = false;
    });

    try {
      final sections = await StudyMaterialService.getSections(_selectedExam);
      if (!mounted) return;
      setState(() {
        _firestoreSections = sections;
        _sectionsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sectionsLoading = false;
        _sectionsLoadError = true;
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

  Future<void> _startMockTest(Map<String,dynamic> testSummary, {required bool timed}) async {
    if (!mounted) return;
    setState(() => _activeMockLoading = true);
    final lang = context.read<LanguageProvider>().languageCode;
    final testId = testSummary['id'] as String? ?? testSummary['firestoreId'] as String?;
    if (testId == null) {
      if (!mounted) return;
      setState(() => _activeMockLoading = false);
      return;
    }
    final fullTest = await MockTestService.getMockTestWithQuestions(_selectedExam, testId);
    if (!mounted) return;

    if (fullTest == null || (fullTest['questions'] as List?)?.isEmpty == true) {
      setState(() => _activeMockLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.get('could_not_load_test', lang), style: GoogleFonts.poppins(fontSize: 12)),
        backgroundColor: const Color(0xFFEF4444),
      ));
      return;
    }

    setState(() => _activeMockLoading = false);

    final durationSeconds = fullTest['duration'] as int? ?? 1200;
    final questions = (fullTest['questions'] as List)
        .cast<Map<String, dynamic>>();

    if (!mounted) return;

    // Navigate to the full-screen Testbook-style mock test
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MockTestScreen(
          examName: _selectedExam,
          testTitle: testSummary['title'] as String? ?? 'Mock Test',
          questions: questions,
          durationMinutes: (durationSeconds / 60).round(),
          correctMarks: 2.0,
          negativeMarks: 0.5,
        ),
      ),
    );
  }

  void _startTimer(int seconds) {
    _timeLeft = seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
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
    final lang = context.watch<LanguageProvider>().languageCode;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(children: [
        _header(lang),
        _examSelector(),
        _tabBar(lang),
        Expanded(child: TabBarView(controller: _tabController, children: [
          _notesTab(lang), _pyqTab(lang), _mockTab(lang), _qrTab(), _resourcesTab(lang),
        ])),
      ]),
      bottomNavigationBar: _bottomNav(lang),
    );
  }

  Widget _header(String lang) => Container(
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
        Text(AppStrings.get('study_material_title', lang), style: GoogleFonts.poppins(
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
              _loadSections();
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
              // Exam names (SSC CGL, etc.) are NOT translated — they are
              // proper nouns / official exam codes, same convention used
              // throughout the app.
              child: Text(e, style: GoogleFonts.poppins(
                  fontSize: 11, fontWeight: FontWeight.w500,
                  color: sel ? Colors.white : Colors.grey.shade600)),
            ),
          );
        },
      ),
    ),
  );

  Widget _tabBar(String lang) => Container(
    color: Colors.white,
    child: TabBar(
      controller: _tabController,
      labelColor: const Color(0xFF1565C0),
      unselectedLabelColor: Colors.grey.shade500,
      indicatorColor: const Color(0xFF1565C0),
      indicatorWeight: 3,
      labelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11),
      tabs: [
        Tab(icon: const Icon(Icons.menu_book, size: 16), text: AppStrings.get('tab_notes', lang)),
        Tab(icon: const Icon(Icons.history_edu, size: 16), text: AppStrings.get('tab_pyq', lang)),
        Tab(icon: const Icon(Icons.quiz, size: 16), text: AppStrings.get('tab_mock_test', lang)),
        Tab(icon: const Icon(Icons.flash_on, size: 16), text: AppStrings.get('tab_quick_rev', lang)),
        Tab(icon: const Icon(Icons.link, size: 16), text: AppStrings.get('tab_resources', lang)),
      ],
    ),
  );

  // ============================================================
  // NOTES TAB — rebuilt to show Subjects -> Parts (accordion) ->
  // Chapters, instead of the old flat Subject -> Topics list.
  // Tapping a Subject card opens _SubjectPartsScreen.
  // ============================================================
  Widget _notesTab(String lang) {
    if (_sectionsLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0)));
    }

    if (_sectionsLoadError) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(AppStrings.get('could_not_load_mocks', lang), style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
          const SizedBox(height: 6),
          Text(AppStrings.get('check_connection_retry', lang), textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadSections,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0)),
            child: Text(AppStrings.get('retry', lang), style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ]),
      ));
    }

    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF42A5F5)]),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          const Icon(Icons.school_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          // NOTE: exam name + topic/note CONTENT below stays untranslated —
          // real educational data from StudyData, not app UI chrome.
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$_selectedExam ${AppStrings.get('notes_suffix', lang)}', style: GoogleFonts.poppins(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
            Text('${_sections.length} ${AppStrings.get('topics_exam_level', lang)}',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
          ])),
        ]),
      ),
      const SizedBox(height: 14),
      ..._sections.map((sec) {
        final List<dynamic> parts = (sec['parts'] as List?) ?? [];
        final color = Color(sec['colorHex'] as int);
        final int totalChapters = parts.fold<int>(
          0,
              (sum, p) => sum + (((p as Map)['chapters'] as List?)?.length ?? 0),
        );

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _SubjectPartsScreen(
                  subjectTitle: sec['title'] as String,
                  color: color,
                  parts: parts,
                ),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
              ),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.menu_book_rounded, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sec['title'] as String, style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E))),
                    const SizedBox(height: 2),
                    Text(
                      parts.isEmpty
                          ? AppStrings.get('content_coming_soon', lang)
                          : '${parts.length} parts • $totalChapters chapters',
                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                )),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ]),
            ),
          ),
        );
      }),
    ]);
  }

  Widget _pyqTab(String lang) {
    if (!_quizStarted) return _quizStart(lang);
    if (_quizIndex >= _pyqs.length) return _result(false, lang);
    return _question(_pyqs[_quizIndex], false, lang);
  }

  Widget _quizStart(String lang) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(width: 90, height: 90,
          decoration: BoxDecoration(color: const Color(0xFF1565C0).withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.history_edu_rounded, size: 44, color: Color(0xFF1565C0))),
      const SizedBox(height: 20),
      Text(AppStrings.get('previous_year_questions', lang), style: GoogleFonts.poppins(
          fontSize: 19, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E))),
      const SizedBox(height: 6),
      Text('${_pyqs.length} ${AppStrings.get('questions_exam_explanations', lang)} • $_selectedExam • ${AppStrings.get('with_explanations', lang)}',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
      const SizedBox(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _badge('${_pyqs.length}', AppStrings.get('questions_badge', lang)),
        const SizedBox(width: 12),
        _badge('2024', AppStrings.get('latest_badge', lang)),
      ]),
      const SizedBox(height: 28),
      SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: () => setState(() { _quizStarted = true; _quizIndex = 0; _score = 0; _selAns = null; _showExp = false; }),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1565C0),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(AppStrings.get('start_practice_btn', lang), style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
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

  Widget _question(Map<String,dynamic> q, bool isMock, String lang) {
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
          Text('${AppStrings.get('q_label', lang)} ${idx+1}/$total', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1565C0))),
          const SizedBox(width: 10),
          Expanded(child: LinearProgressIndicator(
            value: (idx+1)/total,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation(Color(0xFF1565C0)),
            borderRadius: BorderRadius.circular(4), minHeight: 5,
          )),
          const SizedBox(width: 10),
          Text('${AppStrings.get('score_label', lang)} $score', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF10B981))),
        ]),
        const SizedBox(height: 10),
        // Subject/year tags show REAL data (e.g. "Reasoning", "2023") —
        // not translated, same as exam names.
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
          // Question text itself is REAL exam content — not translated.
          child: Text(q['q'] as String, style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A2E), height: 1.5)),
        ),
        const SizedBox(height: 12),
        ...opts.asMap().entries.map((e) {
          final i   = e.key;
          final opt = e.value as String;
          final lbl = ['A','B','C','D'][i];

          Color bg     = Colors.white;
          Color border = Colors.grey.shade200;
          Color txt    = const Color(0xFF374151);
          Color lblBg  = const Color(0xFF1565C0);
          IconData? trailingIcon;
          Color? trailingColor;

          if (selAns != null) {
            if (i == correct) {
              bg     = const Color(0xFF10B981).withOpacity(0.1);
              border = const Color(0xFF10B981);
              txt    = const Color(0xFF10B981);
              lblBg  = const Color(0xFF10B981);
              trailingIcon  = Icons.check_circle;
              trailingColor = const Color(0xFF10B981);
            }
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

              // Award XP for answering a question
              ProgressService.awardXP('pyq_answered', ProgressService.xpPYQAnswered).then((result) {
                if (mounted && result.didRankUp) ProgressWidgets.handleResult(context, result);
              });

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
                // Option text is REAL exam content — not translated.
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
                Text(AppStrings.get('explanation_label', lang), style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1565C0))),
              ]),
              const SizedBox(height: 4),
              // Explanation text is REAL exam content — not translated.
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
                    // Award XP for completing a mock test
                    ProgressService.awardXP('mock_test_completed', ProgressService.xpMockCompleted).then((result) {
                      if (mounted && result.hasUpdate) ProgressWidgets.handleResult(context, result);
                    });
                    // Add to exam history automatically
                    ProgressService.addExamHistory(examName: _selectedExam, status: 'appeared', source: 'app');
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
                  ? (_mockIndex < (_activeMock!['questions'] as List).length - 1 ? AppStrings.get('next_question_btn', lang) : AppStrings.get('see_results_btn', lang))
                  : (_quizIndex < _pyqs.length - 1 ? AppStrings.get('next_question_btn', lang) : AppStrings.get('see_results_btn', lang)),
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

  Widget _result(bool isMock, String lang) {
    final questions = isMock
        ? (_activeMock!['questions'] as List).cast<Map<String,dynamic>>()
        : _pyqs;
    final total = questions.length;
    final s     = isMock ? _mockScore : _score;
    final pct   = total > 0 ? (s / total * 100).round() : 0;
    final c     = pct >= 70 ? const Color(0xFF10B981) : pct >= 50 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);
    final msg   = pct >= 70 ? AppStrings.get('excellent_result', lang) : pct >= 50 ? AppStrings.get('good_effort_result', lang) : AppStrings.get('keep_practicing_result', lang);

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
        Text('$s ${AppStrings.get('out_of_correct', lang)} $total ${AppStrings.get('correct_suffix', lang)}', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade500)),
        const SizedBox(height: 20),

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
                  pct >= 70 ? AppStrings.get('outstanding_performance', lang) : pct >= 50 ? AppStrings.get('on_right_track', lang) : AppStrings.get('dont_give_up', lang),
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: c)),
              Text(
                  pct >= 70 ? AppStrings.get('exam_ready_msg', lang) : pct >= 50 ? AppStrings.get('focus_weak_areas', lang) : AppStrings.get('revise_attempt_again', lang),
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600)),
            ])),
          ]),
        ),
        const SizedBox(height: 20),

        if (isMock && topicTotal.isNotEmpty) ...[
          Align(alignment: Alignment.centerLeft,
              child: Text(AppStrings.get('topic_wise_analysis', lang), style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E)))),
          const SizedBox(height: 10),
          ...topicTotal.entries.map((entry) {
            final subject  = entry.key;
            final tTotal   = entry.value;
            final tCorrect = topicCorrect[subject] ?? 0;
            final tPct     = tTotal > 0 ? (tCorrect / tTotal * 100).round() : 0;
            final tColor   = tPct >= 70 ? const Color(0xFF10B981) : tPct >= 50 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);
            final label    = tPct >= 70 ? AppStrings.get('strong_label', lang) : tPct >= 50 ? AppStrings.get('average_label', lang) : AppStrings.get('weak_label', lang);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
              ),
              // Subject name (e.g. "Reasoning") stays untranslated — real
              // exam-subject data.
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
                Text('$tPct% ${AppStrings.get('accuracy_suffix', lang)}', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
              ]),
            );
          }),
          const SizedBox(height: 20),

          Align(alignment: Alignment.centerLeft,
              child: Text(AppStrings.get('recommendations_title', lang), style: GoogleFonts.poppins(
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
              // _getTip() content is substantial educational guidance —
              // same treatment as syllabus/study content, NOT translated
              // in this pass.
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('💡 ', style: TextStyle(fontSize: 16)),
                Expanded(child: Text(_getTip(entry.key, tPct),
                    style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF374151)))),
              ]),
            );
          }),
          const SizedBox(height: 20),
        ],

        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () => isMock ? _resetMock() : _resetQuiz(),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(AppStrings.get('try_again_btn', lang), style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        )),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: OutlinedButton(
          onPressed: () => isMock ? _resetMock() : _resetQuiz(),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: Color(0xFF1565C0)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(AppStrings.get('back_to_tests_btn', lang), style: GoogleFonts.poppins(
              color: const Color(0xFF1565C0), fontWeight: FontWeight.w600)),
        )),
        const SizedBox(height: 20),
      ]),
    );
  }

  // _getTip() content remains in English — substantial educational
  // guidance text, treated the same as syllabus/study material content,
  // not in scope for this UI-strings translation pass.
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

  Widget _mockTab(String lang) {
    if (_activeMock != null) {
      if (_mockDone) return _result(true, lang);
      final qList = _activeMock!['questions'] as List;
      return _question(qList[_mockIndex] as Map<String,dynamic>, true, lang);
    }

    if (_activeMockLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0)));
    }

    if (_mocksLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0)));
    }

    if (_mockLoadError) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(AppStrings.get('could_not_load_mocks', lang), style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
          const SizedBox(height: 6),
          Text(AppStrings.get('check_connection_retry', lang), textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadMockTests,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0)),
            child: Text(AppStrings.get('retry', lang), style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ]),
      ));
    }

    if (_mocks.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.quiz_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text('${AppStrings.get('no_mock_tests_yet', lang)} $_selectedExam', textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
          const SizedBox(height: 6),
          Text(AppStrings.get('adding_tests_soon', lang), textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
        ]),
      ));
    }

    return ListView(padding: const EdgeInsets.all(16), children: [
      // mt['title']/mt['description'] are real Firestore mock-test
      // content — not translated.
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
                Text(mt['title'] as String? ?? AppStrings.get('tab_mock_test', lang), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E))),
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
                label: Text(AppStrings.get('practice_btn', lang), style: GoogleFonts.poppins(fontSize: 12)),
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
                label: Text('${AppStrings.get('timed_btn', lang)} (${_fmt(mt['duration'] as int? ?? 1200)})', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white)),
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
      // Coming soon banner — shown on all exams below existing tests
      Container(
        margin: const EdgeInsets.only(top: 4, bottom: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.2)),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(child: Text('🚀', style: TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('More mock tests coming soon!',
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: const Color(0xFF1565C0))),
            Text('We are adding more full-length mock tests for $_selectedExam. Stay tuned!',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: Colors.grey.shade500)),
          ])),
        ]),
      ),
    ]);
  }

  // Quick Revision content (sec['title'], item text) is real study
  // material — not translated in this pass.
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

  Widget _bottomNav(String lang) => BottomNavigationBar(
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
    items: [
      BottomNavigationBarItem(icon: const Icon(Icons.home_outlined), activeIcon: const Icon(Icons.home), label: AppStrings.get('nav_home', lang)),
      BottomNavigationBarItem(icon: const Icon(Icons.work_outline), activeIcon: const Icon(Icons.work), label: AppStrings.get('nav_jobs', lang)),
      BottomNavigationBarItem(icon: const Icon(Icons.newspaper_outlined), activeIcon: const Icon(Icons.newspaper), label: AppStrings.get('nav_news', lang)),
      BottomNavigationBarItem(icon: const Icon(Icons.bookmark_outline), activeIcon: const Icon(Icons.bookmark), label: AppStrings.get('nav_saved', lang)),
      BottomNavigationBarItem(icon: const Icon(Icons.person_outline), activeIcon: const Icon(Icons.person), label: AppStrings.get('nav_profile', lang)),
    ],
  );

  // ── FREE RESOURCES DATA (OFFICIAL SITES ONLY) ───────────────
  // Resource titles/subtitles are proper-noun site descriptions —
  // not translated, same convention as Job Detail's Papers tab.
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

  Widget _resourcesTab(String lang) {
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
              Text('${AppStrings.get('free_resources_for', lang)} $_selectedExam',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              Text(AppStrings.get('official_govt_sites_only', lang),
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
              AppStrings.get('resources_disclaimer', lang),
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

// ============================================================
// NEW SCREEN — shown after tapping a Subject card on the Notes
// tab. Shows Parts as expandable accordion sections; Chapters
// listed inside each Part. Tapping a Chapter opens _ChapterScreen.
// Replaces the old flat-topic-list behavior.
// ============================================================
class _SubjectPartsScreen extends StatelessWidget {
  final String subjectTitle;
  final Color color;
  final List<dynamic> parts;

  const _SubjectPartsScreen({
    required this.subjectTitle,
    required this.color,
    required this.parts,
  });

  static Color _diffColorStatic(String d) {
    if (d.contains('Easy')) return const Color(0xFF10B981);
    if (d.contains('Hard')) return const Color(0xFFEF4444);
    return const Color(0xFFF59E0B);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(subjectTitle, style: GoogleFonts.poppins(
            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
      ),
      body: parts.isEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.construction_rounded, size: 56, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text('Content coming soon',
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: const Color(0xFF374151))),
            ],
          ),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: parts.length,
        itemBuilder: (context, i) {
          final part = parts[i] as Map<String, dynamic>;
          final List<dynamic> chapters = (part['chapters'] as List?) ?? [];

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
            ),
            child: ExpansionTile(
              initiallyExpanded: i == 0,
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.folder_open_rounded, color: color, size: 18),
              ),
              title: Text(part['title'] as String? ?? 'Part',
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A2E))),
              subtitle: Text('${chapters.length} chapters',
                  style: GoogleFonts.poppins(fontSize: 11, color: color)),
              children: chapters.map((c) {
                final chapter = c as Map<String, dynamic>;
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _ChapterScreen(chapter: chapter, color: color),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.grey.shade100)),
                    ),
                    child: Row(children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(chapter['title'] as String? ?? '',
                              style: GoogleFonts.poppins(
                                  fontSize: 13, fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1A1A2E))),
                          if (chapter['weightage'] != null || chapter['readTime'] != null)
                            Text(
                              [
                                if (chapter['weightage'] != null) chapter['weightage'],
                                if (chapter['readTime'] != null) chapter['readTime'],
                              ].join(' • '),
                              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500),
                            ),
                        ],
                      )),
                      if (chapter['difficulty'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _diffColorStatic(chapter['difficulty'] as String).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(chapter['difficulty'] as String,
                              style: GoogleFonts.poppins(
                                  fontSize: 10, fontWeight: FontWeight.w600,
                                  color: _diffColorStatic(chapter['difficulty'] as String))),
                        ),
                      const SizedBox(width: 6),
                      Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 18),
                    ]),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}
// ============================================================
// _ChapterScreen — FIXED.
//
// Root cause of the bug: the previous regex matched ANY
// "**bold text**" as a section header — including single-letter
// bold emphasis used inside bullet lists (e.g. "- **P** →
// Proper..." in the Desi Mnemonic section). That fragmented
// every chapter after "Examples" into broken mini-sections,
// which is exactly the garbled/overlapping symptom reported.
//
// Fix: the header regex now ONLY matches bold text that begins
// with one of the 6 known section-title keywords (Textbook
// Definition, Simple Explanation, Examples, Key Core Concepts,
// Desi Mnemonic, Memory Box). Single-letter or short emphasis
// bold inside bullet lists no longer gets misidentified as a
// new section.
//
// Requires: flutter_markdown_plus (already in pubspec.yaml)
// Add this import at the top of study_material_screen.dart:
//   import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
// ============================================================

class _ContentSection {
  final String type;
  final String? heading;
  final String body;
  _ContentSection({required this.type, this.heading, required this.body});
}

class _ChapterScreen extends StatefulWidget {
  final Map<String, dynamic> chapter;
  final Color color;

  const _ChapterScreen({required this.chapter, required this.color});

  @override
  State<_ChapterScreen> createState() => _ChapterScreenState();
}

class _ChapterScreenState extends State<_ChapterScreen> {
  Map<String, dynamic> get chapter => widget.chapter;
  Color get color => widget.color;

  @override
  void initState() {
    super.initState();
    // Award XP when user opens a chapter — fire-and-forget,
    // only show toast if a rank-up happens (avoid toast spam
    // since users might open many chapters in one session).
    ProgressService.awardXP('chapter_read', ProgressService.xpChapterRead).then((result) {
      if (mounted && result.didRankUp) ProgressWidgets.handleResult(context, result);
    });
  }

  // ── Section parser (fixed) ──────────────────────────────────
  // Only matches "**...**" where the inside text starts with one
  // of the known section keywords. This prevents short bold
  // emphasis used for bullet styling (e.g. "**P**", "**C**")
  // from being misidentified as a new section header.
  static final RegExp _headerPattern = RegExp(
    r'\*\*\s*(Textbook Definition|Simple Explanation|Examples?|Key Core Concepts(?:\s*&\s*Facts)?|Desi Mnemonic[^*]*|Memory Box[^*]*|Quick Reference[^*]*)\s*\*\*',
    caseSensitive: false,
  );

  List<_ContentSection> _parseSections(String raw) {
    final matches = _headerPattern.allMatches(raw).toList();

    if (matches.isEmpty) {
      return [_ContentSection(type: 'plain', body: raw.trim())];
    }

    final List<_ContentSection> sections = [];

    for (int i = 0; i < matches.length; i++) {
      final heading = matches[i].group(1)?.trim() ?? '';
      final bodyStart = matches[i].end;
      final bodyEnd = (i + 1 < matches.length) ? matches[i + 1].start : raw.length;
      var body = raw.substring(bodyStart, bodyEnd).trim();
      body = body.replaceFirst(RegExp(r'^\s+'), '');

      sections.add(_ContentSection(
        type: _classify(heading),
        heading: heading,
        body: body,
      ));
    }

    return sections;
  }

  String _classify(String heading) {
    final h = heading.toLowerCase();
    if (h.contains('trap') || h.contains('memory box')) return 'trap';
    if (h.contains('mnemonic')) return 'mnemonic';
    if (h.contains('key core concepts') || h.contains('key concepts')) return 'concepts';
    if (h.contains('example')) return 'examples';
    if (h.contains('simple explanation')) return 'explanation';
    if (h.contains('textbook definition') || h.contains('definition')) return 'definition';
    return 'plain';
  }

  @override
  Widget build(BuildContext context) {
    final String rawContent = chapter['content'] as String? ?? '';
    final sections = _parseSections(rawContent);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: color, foregroundColor: Colors.white, elevation: 0,
        title: Text(chapter['title'] as String? ?? '', style: GoogleFonts.poppins(
            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
        actions: [
          if (chapter['difficulty'] != null)
            Padding(padding: const EdgeInsets.only(right: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                  child: Text(chapter['difficulty'] as String, style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                )),
        ],
      ),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (chapter['weightage'] != null)
              _chip(Icons.bar_chart, '${chapter['weightage']}', color),
            if (chapter['weightage'] != null && chapter['readTime'] != null)
              const SizedBox(width: 8),
            if (chapter['readTime'] != null)
              _chip(Icons.timer_outlined, chapter['readTime'] as String, color),
          ]),
          const SizedBox(height: 16),
          ...sections.map((s) => _buildSectionCard(s)),
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

  Widget _buildSectionCard(_ContentSection section) {
    switch (section.type) {
      case 'trap':
        return _sectionCard(
          section: section,
          icon: Icons.warning_amber_rounded,
          label: section.heading ?? 'Memory Box "Trap"',
          bg: const Color(0xFFFFEBEE),
          border: const Color(0xFFEF5350),
          borderWidth: 1.6,
          labelColor: const Color(0xFFC62828),
          iconColor: const Color(0xFFD32F2F),
          elevated: true,
        );
      case 'mnemonic':
        return _sectionCard(
          section: section,
          icon: Icons.psychology_alt_rounded,
          label: section.heading ?? 'Desi Mnemonic',
          bg: const Color(0xFFFFF8E1),
          border: const Color(0xFFFFC107).withOpacity(0.5),
          borderWidth: 1,
          labelColor: const Color(0xFF92400E),
          iconColor: const Color(0xFFF59E0B),
        );
      case 'concepts':
        return _sectionCard(
          section: section,
          icon: Icons.key_rounded,
          label: section.heading ?? 'Key Core Concepts & Facts',
          bg: color.withOpacity(0.06),
          border: color.withOpacity(0.25),
          borderWidth: 1,
          labelColor: color,
          iconColor: color,
        );
      case 'examples':
        return _sectionCard(
          section: section,
          icon: Icons.edit_note_rounded,
          label: section.heading ?? 'Examples',
          bg: Colors.white,
          border: Colors.grey.shade300,
          borderWidth: 1,
          labelColor: const Color(0xFF374151),
          iconColor: const Color(0xFF6B7280),
          leftAccent: color,
        );
      case 'explanation':
        return _sectionCard(
          section: section,
          icon: Icons.lightbulb_outline_rounded,
          label: section.heading ?? 'Simple Explanation',
          bg: const Color(0xFFE3F2FD),
          border: const Color(0xFF1565C0).withOpacity(0.2),
          borderWidth: 1,
          labelColor: const Color(0xFF0D47A1),
          iconColor: const Color(0xFF1565C0),
        );
      case 'definition':
        return _sectionCard(
          section: section,
          icon: Icons.menu_book_rounded,
          label: section.heading ?? 'Textbook Definition',
          bg: Colors.grey.shade100,
          border: Colors.grey.shade300,
          borderWidth: 1,
          labelColor: const Color(0xFF4B5563),
          iconColor: const Color(0xFF6B7280),
        );
      default:
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
          ),
          child: _markdownBody(section.heading != null
              ? '**${section.heading}**\n\n${section.body}'
              : section.body),
        );
    }
  }

  Widget _sectionCard({
    required _ContentSection section,
    required IconData icon,
    required String label,
    required Color bg,
    required Color border,
    required double borderWidth,
    required Color labelColor,
    required Color iconColor,
    Color? leftAccent,
    bool elevated = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: borderWidth),
        boxShadow: elevated
            ? [BoxShadow(color: const Color(0xFFEF5350).withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))]
            : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (leftAccent != null)
              Container(width: 4,
                  decoration: BoxDecoration(
                    color: leftAccent,
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(14), bottomLeft: Radius.circular(14)),
                  )),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Icon(icon, size: 18, color: iconColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(label,
                            style: GoogleFonts.poppins(
                                fontSize: 13, fontWeight: FontWeight.w700, color: labelColor)),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    _markdownBody(section.body, dense: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _markdownBody(String data, {bool dense = false}) {
    return MarkdownBody(
      data: data,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: GoogleFonts.poppins(
          fontSize: dense ? 12.5 : 13, color: const Color(0xFF374151), height: 1.6,
        ),
        strong: GoogleFonts.poppins(
          fontSize: dense ? 12.5 : 13, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E),
        ),
        em: GoogleFonts.poppins(
          fontSize: dense ? 12.5 : 13, fontStyle: FontStyle.italic, color: color,
        ),
        listBullet: GoogleFonts.poppins(
          fontSize: dense ? 12.5 : 13, color: const Color(0xFF374151),
        ),
        tableHead: GoogleFonts.poppins(
          fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white,
        ),
        tableBody: GoogleFonts.poppins(
          fontSize: 12, color: const Color(0xFF374151), height: 1.5,
        ),
        tableHeadAlign: TextAlign.left,
        tableBorder: TableBorder.all(color: Colors.grey.shade300, width: 1),
        tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        tableColumnWidth: const FlexColumnWidth(),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1)),
        ),
      ),
      builders: {},
    );
  }
}