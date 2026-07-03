import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:examtrack/services/battle_service.dart';
import 'package:examtrack/screens/battle/waiting_room_screen.dart';
import 'package:examtrack/screens/battle/join_battle_screen.dart';

class BattleSetupScreen extends StatefulWidget {
  const BattleSetupScreen({super.key});

  @override
  State<BattleSetupScreen> createState() => _BattleSetupScreenState();
}

class _BattleSetupScreenState extends State<BattleSetupScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Setup state
  String _mode = 'live'; // 'live' | 'challenge'
  String _topicSource = 'exam'; // 'exam' | 'subject'
  final Set<String> _selectedTopics = {};
  int _questionCount = 10;
  int _timerSeconds = 15;
  String _difficulty = 'medium'; // 'easy' | 'medium' | 'hard'
  bool _isCreating = false;

  static const Color _primary = Color(0xFF1565C0);
  static const Color _accent = Color(0xFF7B1FA2);

  final List<int> _questionOptions = [5, 10, 15, 20];
  final List<int> _timerOptions = [10, 15, 20, 30, 45];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    if (_selectedTopics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please select at least one topic',
            style: GoogleFonts.poppins(fontSize: 12)),
        backgroundColor: const Color(0xFFEF4444),
      ));
      return;
    }

    setState(() => _isCreating = true);

    // Join multiple topics into a single string for the Gemini prompt
    final combinedTopic = _selectedTopics.join(', ');

    try {
      final room = await BattleService.createRoom(
        mode: _mode,
        topic: combinedTopic,
        questionCount: _questionCount,
        timerSeconds: _timerSeconds,
        difficulty: _difficulty,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WaitingRoomScreen(room: room),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', ''),
            style: GoogleFonts.poppins(fontSize: 12)),
        backgroundColor: const Color(0xFFEF4444),
      ));
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(children: [
        _header(),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _modeSelector(),
            const SizedBox(height: 20),
            _topicSourceToggle(),
            const SizedBox(height: 12),
            _topicList(),
            const SizedBox(height: 20),
            _questionCountSelector(),
            const SizedBox(height: 20),
            _difficultySelector(),
            const SizedBox(height: 20),
            if (_mode == 'live') _timerSelector(),
            if (_mode == 'live') const SizedBox(height: 20),
            _createButton(),
            const SizedBox(height: 16),
            _joinButton(),
            const SizedBox(height: 40),
          ]),
        )),
      ]),
    );
  }

  Widget _header() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF1565C0), Color(0xFF7B1FA2)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
    ),
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16, right: 16, bottom: 20,
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Text('1v1 Quiz Battle', style: GoogleFonts.poppins(
            color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
        const Spacer(),
        const Text('⚔️', style: TextStyle(fontSize: 24)),
      ]),
      const SizedBox(height: 4),
      Text('Challenge a friend to a quiz battle',
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
    ]),
  );

  Widget _modeSelector() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Battle Mode', style: GoogleFonts.poppins(
          fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E))),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _modeCard(
          'live', '⚡ Live Battle',
          'Both online at the same time',
          const Color(0xFF1565C0),
        )),
        const SizedBox(width: 10),
        Expanded(child: _modeCard(
          'challenge', '📩 Challenge',
          'Answer whenever you\'re ready',
          const Color(0xFF7B1FA2),
        )),
      ]),
    ],
  );

  Widget _modeCard(String mode, String title, String subtitle, Color color) {
    final selected = _mode == mode;
    return GestureDetector(
      onTap: () => setState(() => _mode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color : Colors.grey.shade300, width: 1.5),
          boxShadow: selected ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : [],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF1A1A2E))),
          const SizedBox(height: 4),
          Text(subtitle, style: GoogleFonts.poppins(
              fontSize: 10, color: selected ? Colors.white70 : Colors.grey.shade500)),
        ]),
      ),
    );
  }

  Widget _topicSourceToggle() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Choose Topic By', style: GoogleFonts.poppins(
          fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E))),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _sourceButton('exam', '📋 Exam')),
        const SizedBox(width: 10),
        Expanded(child: _sourceButton('subject', '📚 Subject')),
      ]),
    ],
  );

  Widget _sourceButton(String source, String label) {
    final selected = _topicSource == source;
    return GestureDetector(
      onTap: () => setState(() {
        _topicSource = source;
        _selectedTopics.clear();
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _primary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? _primary : Colors.grey.shade300),
        ),
        child: Center(child: Text(label, style: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF374151)))),
      ),
    );
  }

  Widget _topicList() {
    final topics = _topicSource == 'exam'
        ? BattleTopics.exams
        : BattleTopics.subjects;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_selectedTopics.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '${_selectedTopics.length} selected — questions will mix these topics',
            style: GoogleFonts.poppins(
                fontSize: 11, color: _accent, fontWeight: FontWeight.w600),
          ),
        ),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: topics.map((topic) {
          final selected = _selectedTopics.contains(topic);
          return GestureDetector(
            onTap: () => setState(() {
              if (selected) {
                _selectedTopics.remove(topic);
              } else {
                _selectedTopics.add(topic);
              }
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? _accent : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: selected ? _accent : Colors.grey.shade300),
                boxShadow: selected ? [BoxShadow(
                    color: _accent.withOpacity(0.25), blurRadius: 6)] : [],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (selected) ...[
                  const Icon(Icons.check, size: 13, color: Colors.white),
                  const SizedBox(width: 4),
                ],
                Text(topic, style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : const Color(0xFF374151))),
              ]),
            ),
          );
        }).toList(),
      ),
    ]);
  }

  Widget _questionCountSelector() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Number of Questions', style: GoogleFonts.poppins(
          fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E))),
      const SizedBox(height: 10),
      Row(children: _questionOptions.map((count) {
        final selected = _questionCount == count;
        return Expanded(child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => setState(() => _questionCount = count),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: selected ? _primary : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: selected ? _primary : Colors.grey.shade300),
              ),
              child: Center(child: Text('$count', style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : const Color(0xFF374151)))),
            ),
          ),
        ));
      }).toList()),
    ],
  );

  Widget _difficultySelector() {
    final difficulties = [
      {
        'value': 'easy',
        'label': '😊 Easy',
        'desc': 'Basic level questions',
        'color': const Color(0xFF10B981),
      },
      {
        'value': 'medium',
        'label': '🎯 Medium',
        'desc': 'Exam standard level',
        'color': const Color(0xFFF59E0B),
      },
      {
        'value': 'hard',
        'label': '🔥 Hard',
        'desc': 'Advanced & tricky',
        'color': const Color(0xFFEF5350),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Difficulty Level', style: GoogleFonts.poppins(
            fontSize: 14, fontWeight: FontWeight.w700,
            color: const Color(0xFF1A1A2E))),
        const SizedBox(height: 10),
        Row(children: difficulties.map((d) {
          final selected = _difficulty == d['value'];
          final color = d['color'] as Color;
          return Expanded(child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _difficulty = d['value'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  color: selected ? color.withOpacity(0.12) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? color : Colors.grey.shade300,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Column(children: [
                  Text(d['label'] as String, style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: selected ? color : const Color(0xFF374151))),
                  const SizedBox(height: 2),
                  Text(d['desc'] as String, style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: selected ? color.withOpacity(0.8) : Colors.grey.shade400),
                      textAlign: TextAlign.center),
                ]),
              ),
            ),
          ));
        }).toList()),
      ],
    );
  }

  Widget _timerSelector() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Time Per Question', style: GoogleFonts.poppins(
          fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E))),
      const SizedBox(height: 10),
      Row(children: _timerOptions.map((secs) {
        final selected = _timerSeconds == secs;
        return Expanded(child: Padding(
          padding: const EdgeInsets.only(right: 6),
          child: GestureDetector(
            onTap: () => setState(() => _timerSeconds = secs),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFEF5350) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: selected ? const Color(0xFFEF5350) : Colors.grey.shade300),
              ),
              child: Center(child: Text('${secs}s', style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : const Color(0xFF374151)))),
            ),
          ),
        ));
      }).toList()),
    ],
  );

  Widget _createButton() => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: _isCreating ? null : _createRoom,
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: _isCreating
          ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
        const SizedBox(width: 12),
        Text('Generating questions...', style: GoogleFonts.poppins(
            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      ])
          : Text('⚔️ Create Battle Room', style: GoogleFonts.poppins(
          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
    ),
  );

  Widget _joinButton() => SizedBox(
    width: double.infinity,
    child: OutlinedButton(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const JoinBattleScreen()),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: _primary,
        side: const BorderSide(color: _primary),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text('🔑 Join with Room Code', style: GoogleFonts.poppins(
          fontSize: 14, fontWeight: FontWeight.w600, color: _primary)),
    ),
  );
}