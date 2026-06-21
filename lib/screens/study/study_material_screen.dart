import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';

class StudyMaterialScreen extends StatefulWidget {
  const StudyMaterialScreen({super.key});

  @override
  State<StudyMaterialScreen> createState() =>
      _StudyMaterialScreenState();
}

class _StudyMaterialScreenState
    extends State<StudyMaterialScreen>
    with SingleTickerProviderStateMixin {

  late TabController _tabController;
  String _selectedExam    = 'SSC CGL';
  String _selectedSection = '';
  int _currentQuizIndex   = 0;
  String? _selectedAnswer;
  bool _showExplanation   = false;
  int _score              = 0;
  bool _quizStarted       = false;

  final List<String> _exams = [
    'SSC CGL', 'RRB NTPC', 'IBPS PO',
    'Army Agniveer', 'Punjab Police',
  ];

  // Sections for current exam
  final List<Map<String, dynamic>> _sections = [
    {
      'id': 'reasoning',
      'title': 'Reasoning',
      'icon': Icons.psychology_outlined,
      'color': const Color(0xFF1565C0),
      'topicCount': 8,
    },
    {
      'id': 'quantitative',
      'title': 'Maths',
      'icon': Icons.calculate_outlined,
      'color': const Color(0xFFE65100),
      'topicCount': 7,
    },
    {
      'id': 'english',
      'title': 'English',
      'icon': Icons.menu_book_outlined,
      'color': const Color(0xFF880E4F),
      'topicCount': 3,
    },
    {
      'id': 'general-awareness',
      'title': 'GK',
      'icon': Icons.public_outlined,
      'color': const Color(0xFF1B5E20),
      'topicCount': 4,
    },
  ];

  // Topics per section
  final Map<String, List<Map<String, dynamic>>> _topics = {
    'reasoning': [
      {'title': 'Analogies', 'difficulty': 'Easy', 'weightage': '3-4 Qs'},
      {'title': 'Coding-Decoding', 'difficulty': 'Easy', 'weightage': '2-3 Qs'},
      {'title': 'Blood Relations', 'difficulty': 'Medium', 'weightage': '2-3 Qs'},
      {'title': 'Number & Letter Series', 'difficulty': 'Easy', 'weightage': '3-4 Qs'},
      {'title': 'Syllogism', 'difficulty': 'Medium', 'weightage': '2-3 Qs'},
      {'title': 'Direction & Distance', 'difficulty': 'Easy', 'weightage': '2-3 Qs'},
      {'title': 'Ranking & Arrangement', 'difficulty': 'Easy', 'weightage': '1-2 Qs'},
      {'title': 'Matrix & Figures', 'difficulty': 'Medium', 'weightage': '2-3 Qs'},
    ],
    'quantitative': [
      {'title': 'Number System', 'difficulty': 'Medium', 'weightage': '2-3 Qs'},
      {'title': 'Percentage', 'difficulty': 'Easy', 'weightage': '3-4 Qs'},
      {'title': 'Profit & Loss', 'difficulty': 'Easy', 'weightage': '3-4 Qs'},
      {'title': 'Simple & Compound Interest', 'difficulty': 'Medium', 'weightage': '2-3 Qs'},
      {'title': 'Time & Work', 'difficulty': 'Medium', 'weightage': '3-4 Qs'},
      {'title': 'Speed, Distance & Time', 'difficulty': 'Medium', 'weightage': '3-4 Qs'},
      {'title': 'Geometry & Mensuration', 'difficulty': 'Hard', 'weightage': '4-5 Qs'},
    ],
    'english': [
      {'title': 'Grammar Rules', 'difficulty': 'Medium', 'weightage': '5-6 Qs'},
      {'title': 'Synonyms & Antonyms', 'difficulty': 'Medium', 'weightage': '4-5 Qs'},
      {'title': 'Reading Comprehension', 'difficulty': 'Hard', 'weightage': '5-6 Qs'},
    ],
    'general-awareness': [
      {'title': 'Indian History', 'difficulty': 'Easy', 'weightage': '3-4 Qs'},
      {'title': 'Indian Geography', 'difficulty': 'Easy', 'weightage': '3-4 Qs'},
      {'title': 'Indian Polity', 'difficulty': 'Medium', 'weightage': '4-5 Qs'},
      {'title': 'Static GK', 'difficulty': 'Easy', 'weightage': '5-6 Qs'},
    ],
  };

  // PYQ questions
  final List<Map<String, dynamic>> _pyqs = [
    {
      'subject': 'Reasoning',
      'topic': 'Analogies',
      'year': 2024,
      'question': 'Doctor : Patient :: Teacher : ?',
      'options': ['School', 'Student', 'Book', 'Class'],
      'correct': 1,
      'explanation': 'A Doctor treats a Patient. Similarly, a Teacher teaches a Student. The relationship is professional-beneficiary.',
    },
    {
      'subject': 'Maths',
      'topic': 'Percentage',
      'year': 2024,
      'question': 'A number is increased by 20% then decreased by 20%. Net change?',
      'options': ['No change', '4% decrease', '4% increase', '2% decrease'],
      'correct': 1,
      'explanation': 'Net = A + B + AB/100 = 20 + (-20) + (20×-20)/100 = -4%. So 4% decrease.',
    },
    {
      'subject': 'Maths',
      'topic': 'Profit & Loss',
      'year': 2024,
      'question': 'Bought for ₹200, sold for ₹250. Profit percentage?',
      'options': ['20%', '25%', '50%', '15%'],
      'correct': 1,
      'explanation': 'Profit = ₹50. Profit% = (50/200)×100 = 25%',
    },
    {
      'subject': 'GK',
      'topic': 'Polity',
      'year': 2024,
      'question': 'Which Article is called Heart & Soul of Constitution?',
      'options': ['Article 14', 'Article 19', 'Article 21', 'Article 32'],
      'correct': 3,
      'explanation': 'Article 32 (Right to Constitutional Remedies) is called Heart & Soul by Dr. Ambedkar.',
    },
    {
      'subject': 'GK',
      'topic': 'History',
      'year': 2023,
      'question': 'Dandi March started on which date?',
      'options': ['12 March 1930', '6 April 1930', '15 Aug 1930', '26 Jan 1930'],
      'correct': 0,
      'explanation': 'Gandhi started Dandi March on 12 March 1930, reached Dandi on 6 April 1930.',
    },
    {
      'subject': 'Maths',
      'topic': 'Speed & Distance',
      'year': 2023,
      'question': 'A train 150m long passes a pole in 15s. Speed in km/h?',
      'options': ['32 km/h', '36 km/h', '40 km/h', '54 km/h'],
      'correct': 1,
      'explanation': 'Speed = 150/15 = 10 m/s = 10 × 18/5 = 36 km/h',
    },
    {
      'subject': 'English',
      'topic': 'Synonyms',
      'year': 2024,
      'question': 'Choose the synonym of BENEVOLENT',
      'options': ['Cruel', 'Generous', 'Selfish', 'Arrogant'],
      'correct': 1,
      'explanation': 'Benevolent means well-meaning and kindly. Generous is the correct synonym.',
    },
    {
      'subject': 'Maths',
      'topic': 'Time & Work',
      'year': 2024,
      'question': 'A does work in 10 days, B in 15 days. Together?',
      'options': ['5 days', '6 days', '8 days', '12 days'],
      'correct': 1,
      'explanation': 'A=1/10, B=1/15. Together=1/10+1/15=5/30=1/6. So 6 days.',
    },
    {
      'subject': 'Reasoning',
      'topic': 'Direction',
      'year': 2024,
      'question': 'Ravi walks 5km North, 3km East, 5km South. Distance from start?',
      'options': ['2km', '3km', '5km', '8km'],
      'correct': 1,
      'explanation': '5km N + 5km S cancels. Only 3km East remains. Distance = 3km',
    },
    {
      'subject': 'GK',
      'topic': 'Geography',
      'year': 2024,
      'question': 'Longest river in India?',
      'options': ['Brahmaputra', 'Godavari', 'Ganga', 'Yamuna'],
      'correct': 2,
      'explanation': 'Ganga is longest in India at 2525 km. Indus is longer overall but mostly in Pakistan.',
    },
  ];

  final List<Map<String, dynamic>> _quickRevision = [
    {
      'title': 'Key Formulas',
      'icon': Icons.functions,
      'color': const Color(0xFF1565C0),
      'items': [
        'SI = PRT/100',
        'CI = P(1 + R/100)ⁿ - P',
        'Profit% = (Profit/CP) × 100',
        'Speed = Distance/Time',
        '1 km/h = 5/18 m/s',
        'Area circle = πr²',
        'Volume cylinder = πr²h',
        'Average speed = 2S₁S₂/(S₁+S₂)',
        'HCF × LCM = Product of two numbers',
      ]
    },
    {
      'title': 'Important GK Facts',
      'icon': Icons.star_outline,
      'color': const Color(0xFF1B5E20),
      'items': [
        'Highest peak in India: Kangchenjunga (8586m)',
        'Longest river in India: Ganga (2525km)',
        'Largest state: Rajasthan | Smallest: Goa',
        'Father of Constitution: Dr. B.R. Ambedkar',
        'Art 32 = Heart & Soul of Constitution',
        '1st PM: Nehru | 1st President: Rajendra Prasad',
        'National Animal: Tiger | National Bird: Peacock',
        'Republic Day: 26 Jan 1950 | Independence: 15 Aug 1947',
        'Dandi March: 12 March 1930',
      ]
    },
    {
      'title': 'Trick Questions',
      'icon': Icons.warning_amber_outlined,
      'color': const Color(0xFFE65100),
      'items': [
        'Highest peak in INDIA = Kangchenjunga (NOT Everest)',
        'National Sport = Hockey (NOT Cricket)',
        'Constitution ADOPTED 26 Nov 1949, EFFECTIVE 26 Jan 1950',
        'Vande Mataram = National SONG (not anthem)',
        'Jana Gana Mana = National ANTHEM',
        'Ganga = longest IN INDIA, Indus is longer overall',
        '2 is the ONLY even prime number',
        '1 is NEITHER prime NOR composite',
      ]
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _difficultyColor(String d) {
    switch (d) {
      case 'Easy':   return const Color(0xFF10B981);
      case 'Medium': return const Color(0xFFF59E0B);
      case 'Hard':   return const Color(0xFFEF4444);
      default:       return const Color(0xFF6B7280);
    }
  }

  void _showTopicDetail(Map<String, dynamic> topic,
      Map<String, dynamic> section) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _TopicDetailScreen(
          topic: topic,
          sectionColor: section['color'] as Color,
          sectionTitle: section['title'] as String,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          _buildHeader(),
          _buildExamSelector(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildNotesTab(),
                _buildPYQTab(),
                _buildMockTestTab(),
                _buildQuickRevisionTab(),
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
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back,
                color: Colors.white),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Study Material',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              Text('Prepare smarter, score higher',
                  style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 12)),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.bookmark_outline,
                color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildExamSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(
        height: 38,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _exams.length,
          itemBuilder: (_, i) {
            final exam = _exams[i];
            final selected = _selectedExam == exam;
            return GestureDetector(
              onTap: () => setState(() => _selectedExam = exam),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF1565C0)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF1565C0)
                        : const Color(0xFFD1D5DB),
                  ),
                ),
                child: Text(exam,
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: selected
                            ? Colors.white
                            : const Color(0xFF6B7280))),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF1565C0),
        unselectedLabelColor: const Color(0xFF6B7280),
        indicatorColor: const Color(0xFF1565C0),
        indicatorWeight: 3,
        labelStyle: GoogleFonts.poppins(
            fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            GoogleFonts.poppins(fontSize: 11),
        tabs: const [
          Tab(icon: Icon(Icons.menu_book, size: 18),
              text: 'Notes'),
          Tab(icon: Icon(Icons.history_edu, size: 18),
              text: 'PYQ'),
          Tab(icon: Icon(Icons.quiz, size: 18),
              text: 'Mock Test'),
          Tab(icon: Icon(Icons.flash_on, size: 18),
              text: 'Quick Rev'),
        ],
      ),
    );
  }

  // ── NOTES TAB ─────────────────────────────────────────
  Widget _buildNotesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Progress banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.school_rounded,
                  color: Colors.white, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$_selectedExam Notes',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    Text('22 topics across 4 subjects',
                        style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Sections
        ..._sections.map((section) {
          final topics =
              _topics[section['id']] ?? [];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: (section['color'] as Color)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(section['icon'] as IconData,
                        color: section['color'] as Color,
                        size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(section['title'] as String,
                      style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A1A2E))),
                  const Spacer(),
                  Text('${topics.length} topics',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF6B7280))),
                ],
              ),
              const SizedBox(height: 10),
              ...topics.map((topic) => GestureDetector(
                onTap: () =>
                    _showTopicDetail(topic, section),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: section['color'] as Color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(topic['title'] as String,
                                style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(
                                        0xFF1A1A2E))),
                            Text(
                                '${topic['weightage']} per paper',
                                style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: const Color(
                                        0xFF6B7280))),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _difficultyColor(
                                  topic['difficulty'] as String)
                              .withOpacity(0.1),
                          borderRadius:
                              BorderRadius.circular(6),
                        ),
                        child: Text(
                            topic['difficulty'] as String,
                            style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _difficultyColor(
                                    topic['difficulty']
                                        as String))),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right,
                          color: Color(0xFF9CA3AF),
                          size: 18),
                    ],
                  ),
                ),
              )),
              const SizedBox(height: 8),
            ],
          );
        }),
      ],
    );
  }

  // ── PYQ TAB ───────────────────────────────────────────
  Widget _buildPYQTab() {
    if (!_quizStarted) {
      return _buildPYQStart();
    }
    if (_currentQuizIndex >= _pyqs.length) {
      return _buildQuizResult();
    }
    final q = _pyqs[_currentQuizIndex];
    return _buildQuizQuestion(q);
  }

  Widget _buildPYQStart() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.history_edu_rounded,
                  size: 50, color: Color(0xFF1565C0)),
            ),
            const SizedBox(height: 24),
            Text('Previous Year Questions',
                style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A2E))),
            const SizedBox(height: 8),
            Text(
              '${_pyqs.length} questions from SSC CGL 2023-24\nWith detailed explanations',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF6B7280),
                  height: 1.5),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _statBadge('${_pyqs.length}', 'Questions'),
                const SizedBox(width: 16),
                _statBadge('4', 'Subjects'),
                const SizedBox(width: 16),
                _statBadge('2024', 'Latest'),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => setState(() {
                  _quizStarted      = true;
                  _currentQuizIndex = 0;
                  _score            = 0;
                  _selectedAnswer   = null;
                  _showExplanation  = false;
                }),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  padding: const EdgeInsets.symmetric(
                      vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Start Practice',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBadge(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1565C0))),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: const Color(0xFF6B7280))),
        ],
      ),
    );
  }

  Widget _buildQuizQuestion(Map<String, dynamic> q) {
    final options = q['options'] as List<dynamic>;
    final correct = q['correct'] as int;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress
          Row(
            children: [
              Text(
                'Q ${_currentQuizIndex + 1}/${_pyqs.length}',
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1565C0)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LinearProgressIndicator(
                  value: (_currentQuizIndex + 1) / _pyqs.length,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation(
                      Color(0xFF1565C0)),
                  borderRadius: BorderRadius.circular(4),
                  minHeight: 6,
                ),
              ),
              const SizedBox(width: 12),
              Text('Score: $_score',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF10B981))),
            ],
          ),
          const SizedBox(height: 16),

          // Tags
          Row(
            children: [
              _tag(q['subject'] as String,
                  const Color(0xFF1565C0)),
              const SizedBox(width: 8),
              _tag(q['topic'] as String,
                  const Color(0xFF6B7280)),
              const SizedBox(width: 8),
              _tag('${q['year']}',
                  const Color(0xFF10B981)),
            ],
          ),
          const SizedBox(height: 16),

          // Question
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10)],
            ),
            child: Text(q['question'] as String,
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1A2E),
                    height: 1.5)),
          ),
          const SizedBox(height: 16),

          // Options
          ...options.asMap().entries.map((entry) {
            final idx = entry.key;
            final opt = entry.value as String;
            final label =
                ['A', 'B', 'C', 'D'][idx];
            Color bgColor = Colors.white;
            Color borderColor = Colors.grey.shade200;
            Color textColor = const Color(0xFF374151);
            Color labelBg = const Color(0xFF1565C0);

            if (_selectedAnswer != null) {
              if (idx == correct) {
                bgColor = const Color(0xFF10B981)
                    .withOpacity(0.1);
                borderColor = const Color(0xFF10B981);
                textColor = const Color(0xFF10B981);
                labelBg = const Color(0xFF10B981);
              } else if (_selectedAnswer == label &&
                  idx != correct) {
                bgColor = const Color(0xFFEF4444)
                    .withOpacity(0.1);
                borderColor = const Color(0xFFEF4444);
                textColor = const Color(0xFFEF4444);
                labelBg = const Color(0xFFEF4444);
              }
            }

            return GestureDetector(
              onTap: _selectedAnswer == null
                  ? () {
                      setState(() {
                        _selectedAnswer = label;
                        _showExplanation = true;
                        if (idx == correct) _score++;
                      });
                    }
                  : null,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: labelBg,
                        borderRadius:
                            BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(label,
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(opt,
                          style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: textColor,
                              fontWeight: _selectedAnswer != null &&
                                      idx == correct
                                  ? FontWeight.w600
                                  : FontWeight.w400)),
                    ),
                    if (_selectedAnswer != null)
                      Icon(
                        idx == correct
                            ? Icons.check_circle
                            : _selectedAnswer == label
                                ? Icons.cancel
                                : null,
                        color: idx == correct
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                        size: 20,
                      ),
                  ],
                ),
              ),
            );
          }),

          // Explanation
          if (_showExplanation) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0)
                    .withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF1565C0)
                        .withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.lightbulb_outline,
                        color: Color(0xFF1565C0), size: 16),
                    const SizedBox(width: 6),
                    Text('Explanation',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1565C0))),
                  ]),
                  const SizedBox(height: 6),
                  Text(q['explanation'] as String,
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF374151),
                          height: 1.4)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => setState(() {
                  _currentQuizIndex++;
                  _selectedAnswer  = null;
                  _showExplanation = false;
                }),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  padding: const EdgeInsets.symmetric(
                      vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12)),
                ),
                child: Text(
                  _currentQuizIndex < _pyqs.length - 1
                      ? 'Next Question →'
                      : 'See Results',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color)),
    );
  }

  Widget _buildQuizResult() {
    final pct = (_score / _pyqs.length * 100).round();
    Color resultColor;
    String resultText;
    if (pct >= 70) {
      resultColor = const Color(0xFF10B981);
      resultText  = 'Excellent!';
    } else if (pct >= 50) {
      resultColor = const Color(0xFFF59E0B);
      resultText  = 'Good effort!';
    } else {
      resultColor = const Color(0xFFEF4444);
      resultText  = 'Keep practicing!';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: resultColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text('$pct%',
                    style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: resultColor)),
              ),
            ),
            const SizedBox(height: 16),
            Text(resultText,
                style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: resultColor)),
            const SizedBox(height: 8),
            Text('$_score out of ${_pyqs.length} correct',
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFF6B7280))),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => setState(() {
                  _quizStarted      = false;
                  _currentQuizIndex = 0;
                  _score            = 0;
                  _selectedAnswer   = null;
                  _showExplanation  = false;
                }),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  padding: const EdgeInsets.symmetric(
                      vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12)),
                ),
                child: Text('Practice Again',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── MOCK TEST TAB ─────────────────────────────────────
  Widget _buildMockTestTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _mockTestCard(
          'Full Length Mock Test 1',
          '100 questions • 60 mins',
          'All sections • SSC CGL pattern',
          Icons.timer_outlined,
          const Color(0xFF1565C0),
          false,
        ),
        _mockTestCard(
          'Reasoning Mock Test',
          '25 questions • 20 mins',
          'Analogies, Series, Coding-Decoding',
          Icons.psychology_outlined,
          const Color(0xFF1565C0),
          false,
        ),
        _mockTestCard(
          'Maths Mock Test',
          '25 questions • 20 mins',
          'Percentage, P&L, SI/CI, Geometry',
          Icons.calculate_outlined,
          const Color(0xFFE65100),
          false,
        ),
        _mockTestCard(
          'English Mock Test',
          '25 questions • 20 mins',
          'Grammar, Synonyms, RC',
          Icons.menu_book_outlined,
          const Color(0xFF880E4F),
          false,
        ),
        _mockTestCard(
          'GK Mock Test',
          '25 questions • 20 mins',
          'History, Geography, Polity, Static GK',
          Icons.public_outlined,
          const Color(0xFF1B5E20),
          false,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFFF59E0B).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_outline,
                  color: Color(0xFFF59E0B)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'More mock tests coming soon. Full length timed tests with performance analytics.',
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF92400E)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mockTestCard(
      String title, String subtitle, String desc,
      IconData icon, Color color, bool locked) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title — Coming soon!',
                style: GoogleFonts.poppins()),
            backgroundColor: const Color(0xFF1C1C1E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A1A2E))),
                  Text(subtitle,
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.w600)),
                  Text(desc,
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF9CA3AF))),
                ],
              ),
            ),
            Icon(
              locked
                  ? Icons.lock_outline
                  : Icons.arrow_forward_ios,
              color: const Color(0xFF9CA3AF),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // ── QUICK REVISION TAB ────────────────────────────────
  Widget _buildQuickRevisionTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: _quickRevision.map((section) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(section['icon'] as IconData,
                    color: section['color'] as Color,
                    size: 20),
                const SizedBox(width: 8),
                Text(section['title'] as String,
                    style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A2E))),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8)],
              ),
              child: Column(
                children: (section['items'] as List)
                    .asMap()
                    .entries
                    .map((e) {
                  final isLast = e.key ==
                      (section['items'] as List).length - 1;
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 24, height: 24,
                              decoration: BoxDecoration(
                                color: (section['color'] as Color)
                                    .withOpacity(0.1),
                                borderRadius:
                                    BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                    '${e.key + 1}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight:
                                            FontWeight.w700,
                                        color: section['color']
                                            as Color)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(e.value as String,
                                  style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: const Color(
                                          0xFF374151),
                                      height: 1.4)),
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        Divider(
                            height: 1,
                            color: Colors.grey.shade100),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: 1,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF1565C0),
      unselectedItemColor: const Color(0xFF9CA3AF),
      selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11),
      onTap: (i) {
        switch (i) {
          case 0: Navigator.pushReplacementNamed(
              context, '/home'); break;
          case 1: Navigator.pushReplacementNamed(
              context, '/jobs'); break;
          case 2: Navigator.pushReplacementNamed(
              context, '/current-affairs'); break;
          case 3: Navigator.pushReplacementNamed(
              context, '/saved'); break;
          case 4: Navigator.pushReplacementNamed(
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

// ── Topic Detail Screen ───────────────────────────────────
class _TopicDetailScreen extends StatelessWidget {
  final Map<String, dynamic> topic;
  final Color sectionColor;
  final String sectionTitle;

  const _TopicDetailScreen({
    required this.topic,
    required this.sectionColor,
    required this.sectionTitle,
  });

  // Topic content map
  static const Map<String, String> _content = {
    'Analogies': 'An analogy shows relationship between two pairs of words.\n\nTypes:\n• Synonyms: Hot:Warm :: Cold:Cool\n• Antonyms: Day:Night :: Light:Dark\n• Part-Whole: Wheel:Car :: Petal:Flower\n• Function: Pen:Write :: Knife:Cut\n\nTIP: First identify the relationship in the given pair, then find the same relationship in options.\n\nCommon relationships:\n• Tool-Work: Pen writes, Axe cuts\n• Animal-Young: Cow-Calf, Horse-Foal, Dog-Puppy\n• Animal-Sound: Lion-Roar, Snake-Hiss, Frog-Croak\n• Country-Capital: India-Delhi, France-Paris',
    'Coding-Decoding': 'Coding is a method of transmitting messages in a secret way.\n\nTypes:\n1. Letter Coding: Each letter substituted by another\n   APPLE = BQQMF → shift +1\n\n2. Number Coding:\n   A=1, B=2 ... Z=26\n   DOOR = 4+15+15+18 = 52\n\n3. Mirror coding: A↔Z, B↔Y, C↔X...\n\n4. Reverse alphabet: A=26, B=25 ... Z=1\n\nTIP: Always find the shift pattern first. Check both forward (+) and reverse (-) shifts.',
    'Blood Relations': 'Key Relationships:\n• Parents: Father, Mother\n• Siblings: Brother, Sister\n• Grandparents: Grandfather, Grandmother\n• Spouse: Husband, Wife\n• Uncle/Aunt: Father\'s or Mother\'s sibling\n• Nephew/Niece: Sibling\'s child\n• Cousin: Uncle/Aunt\'s child\n• In-laws: Spouse\'s family\n\nTIP: Always draw a family tree. Use M for Male, F for Female. Mark gender clearly at each node.',
    'Number & Letter Series': 'Number Series Types:\n1. Arithmetic: +2,+3,+4... (2,5,9,14,20...)\n2. Geometric: ×2,×3 (3,6,12,24...)\n3. Square series: 1,4,9,16,25... differences = 3,5,7,9\n4. Cube series: 1,8,27,64... differences = 7,19,37\n5. Prime series: 2,3,5,7,11,13,17,19,23...\n6. Fibonacci: 1,1,2,3,5,8,13,21...\n\nLetter Series:\n• A,C,E,G (skip 1)\n• A,D,G,J (skip 2)\n• Z,X,V,T (reverse, skip 1)',
    'Syllogism': 'Rules:\n1. All A are B + All B are C = All A are C ✅\n2. All A are B + No B are C = No A are C ✅\n3. Some A are B + All B are C = Some A are C ✅\n4. All A are B ≠ All B are A (NOT reversible)\n\nVenn Diagram Method:\n• Draw circles for each category\n• Check if conclusion is ALWAYS true\n• Only ALWAYS true = valid conclusion\n\nTIP: Some A are B = at least one A is B',
    'Direction & Distance': 'Basic Directions:\n         North\n    NW ←  |  → NE\nWest ----+---- East\n    SW ←  |  → SE\n         South\n\nLeft Turn: N→W→S→E→N (anticlockwise)\nRight Turn: N→E→S→W→N (clockwise)\n\nDistance = √(horizontal² + vertical²)\n\nExample:\n5km N + 3km E + 5km S\n= 5N and 5S cancel\n= only 3km East remains\nDistance = 3km',
    'Percentage': 'Key Formulas:\n• x% of y = (x×y)/100\n• % increase = (Increase/Original) × 100\n• % decrease = (Decrease/Original) × 100\n\nFraction Equivalents:\n1/2=50%, 1/3=33.33%, 1/4=25%\n1/5=20%, 1/6=16.67%, 1/8=12.5%\n1/10=10%, 1/20=5%\n\nSuccessive Change:\nNet = A + B + AB/100\nExample: +10% then +20%\n= 10+20+(10×20/100) = +32%\n\nPopulation Formula:\nP(1 + r/100)^n',
    'Profit & Loss': 'Key Terms:\n• CP = Cost Price (bought at)\n• SP = Selling Price (sold at)\n• Profit = SP - CP (SP > CP)\n• Loss = CP - SP (CP > SP)\n\nFormulas:\n• Profit% = (Profit/CP) × 100\n• Loss% = (Loss/CP) × 100\n• SP = CP × (100+P%)/100\n• CP = SP × 100/(100+P%)\n\nDiscount (on Marked Price):\n• Discount% = (Discount/MP) × 100\n\nTRICK: If sold at x% profit and x% loss both:\nAlways a LOSS = x²/100 %',
    'Grammar Rules': 'Parts of Speech: Noun, Pronoun, Verb, Adjective, Adverb, Preposition, Conjunction, Interjection\n\nSubject-Verb Agreement:\n• Each/Every/Either/Neither → SINGULAR verb\n• Two subjects joined by or/nor → verb agrees with nearer subject\n• Collective noun (team, jury) → SINGULAR\n\nCommon Errors:\n• Fewer (countable) vs Less (uncountable)\n• Number (countable) vs Amount (uncountable)\n• Between (two) vs Among (more than two)\n• Bring (towards speaker) vs Take (away)\n• Lie/Lay: Lie=recline, Lay=to place something',
    'Synonyms & Antonyms': 'Important Synonyms:\n• Abundant = Plentiful, Ample\n• Benevolent = Kind, Generous\n• Candid = Frank, Honest\n• Diligent = Hardworking, Industrious\n• Frugal = Thrifty, Economical\n\nImportant Antonyms:\n• Benevolent ↔ Malevolent\n• Diligent ↔ Indolent/Lazy\n• Frugal ↔ Extravagant\n• Gregarious ↔ Introverted\n• Verbose ↔ Concise\n\nTIP: Learn word roots:\nbene=good, mal=bad\npro=for, anti=against\npre=before, post=after',
  };

  @override
  Widget build(BuildContext context) {
    final content = _content[topic['title']] ??
        'Detailed notes for ${topic['title']} coming soon.\n\nThis topic has ${topic['weightage']} per paper in ${topic['difficulty'] == 'Easy' ? 'basic' : topic['difficulty'] == 'Medium' ? 'moderate' : 'advanced'} difficulty level.';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: sectionColor,
        foregroundColor: Colors.white,
        title: Text(topic['title'] as String,
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16)),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                topic['difficulty'] as String,
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats row
            Row(
              children: [
                _infoChip(Icons.bar_chart,
                    '${topic['weightage']} per paper',
                    sectionColor),
                const SizedBox(width: 8),
                _infoChip(Icons.subject,
                    sectionTitle, sectionColor),
              ],
            ),
            const SizedBox(height: 16),

            // Content
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10)],
              ),
              child: Text(
                content,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFF374151),
                    height: 1.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label,
      Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
