import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:examtrack/services/battle_service.dart';
import 'package:examtrack/screens/battle/battle_result_screen.dart';

class LiveBattleScreen extends StatefulWidget {
  final BattleRoom room;
  const LiveBattleScreen({super.key, required this.room});

  @override
  State<LiveBattleScreen> createState() => _LiveBattleScreenState();
}

class _LiveBattleScreenState extends State<LiveBattleScreen> {
  late StreamSubscription<BattleRoom> _roomSub;
  BattleRoom? _currentRoom;

  // Local game state
  int _currentIndex = 0;
  int _myScore = 0;
  int? _selectedAnswer;
  bool _answered = false;
  bool _navigating = false;

  // Timer
  Timer? _questionTimer;
  int _timeLeft = 15;

  late String _myPlayerKey;

  static const Color _primary = Color(0xFF1565C0);
  static const Color _accent = Color(0xFF7B1FA2);

  @override
  void initState() {
    super.initState();
    _currentRoom = widget.room;
    _myPlayerKey = BattleService.getMyPlayerKey(widget.room);
    _timeLeft = widget.room.timerSeconds;

    // Start timer for live mode
    if (widget.room.mode == 'live') _startTimer();

    // Watch for opponent completion / room updates
    _roomSub = BattleService.watchRoom(widget.room.roomCode).listen(
          (room) {
        if (!mounted) return;
        setState(() => _currentRoom = room);

        if (!_navigating && room.isCompleted) {
          _navigating = true;
          _goToResults(room);
        }
      },
    );
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    _roomSub.cancel();
    super.dispose();
  }

  void _startTimer() {
    _questionTimer?.cancel();
    _timeLeft = (_currentRoom ?? widget.room).timerSeconds;
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _timeLeft--);
      if (_timeLeft <= 0) {
        t.cancel();
        if (!_answered) _submitAnswer(-1); // timed out
      }
    });
  }

  Future<void> _submitAnswer(int answerIndex) async {
    if (_answered) return;
    _questionTimer?.cancel();

    final questions = (_currentRoom ?? widget.room).questions;
    final question = questions[_currentIndex];
    final correctIndex = question['correctIndex'] as int;
    final isCorrect = answerIndex == correctIndex;

    setState(() {
      _selectedAnswer = answerIndex;
      _answered = true;
      if (isCorrect) _myScore++;
    });

    // Submit to Firestore
    await BattleService.submitAnswer(
      roomCode: widget.room.roomCode,
      playerKey: _myPlayerKey,
      questionIndex: _currentIndex,
      answerIndex: answerIndex,
      isCorrect: isCorrect,
    );

    // Wait 1.5s to show correct answer, then move on
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    if (_currentIndex < questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswer = null;
        _answered = false;
      });
      if (widget.room.mode == 'live') _startTimer();
    } else {
      // Last question — mark done
      await BattleService.markPlayerDone(
        roomCode: widget.room.roomCode,
        playerKey: _myPlayerKey,
        finalScore: _myScore,
      );
    }
  }

  void _goToResults(BattleRoom room) {
    _questionTimer?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => BattleResultScreen(room: room)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = _currentRoom ?? widget.room;
    final questions = room.questions;
    if (questions.isEmpty) return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );

    final question = questions[_currentIndex];
    final options = List<String>.from(question['options'] as List);
    final correctIndex = question['correctIndex'] as int;

    // Get opponent info
    final opponentKey = _myPlayerKey == 'p1' ? 'p2' : 'p1';
    final opponent = room.players[opponentKey] as Map?;
    final opponentScore = opponent != null
        ? (opponent['score'] as int? ?? 0) : 0;
    final opponentName = opponent != null
        ? (opponent['name'] as String? ?? 'Opponent') : 'Waiting...';

    final totalQuestions = questions.length;
    final progress = (_currentIndex + 1) / totalQuestions;
    final timerPercent = _timeLeft / room.timerSeconds;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Column(children: [
          // Header with scores
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF7B1FA2)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16, right: 16, bottom: 16,
            ),
            child: Column(children: [
              // Score row
              Row(children: [
                // My score
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('You', style: GoogleFonts.poppins(
                      color: Colors.white70, fontSize: 11)),
                  Text('$_myScore', style: GoogleFonts.poppins(
                      color: Colors.white, fontSize: 28,
                      fontWeight: FontWeight.w800)),
                ])),
                // VS
                Column(children: [
                  Text('Q${_currentIndex + 1}/$totalQuestions',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  const Text('⚔️', style: TextStyle(fontSize: 20)),
                ]),
                // Opponent score
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(opponentName, style: GoogleFonts.poppins(
                      color: Colors.white70, fontSize: 11),
                      overflow: TextOverflow.ellipsis),
                  Text('$opponentScore', style: GoogleFonts.poppins(
                      color: Colors.white, fontSize: 28,
                      fontWeight: FontWeight.w800)),
                ])),
              ]),
              const SizedBox(height: 10),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                  minHeight: 5,
                ),
              ),
            ]),
          ),

          // Timer (live mode only)
          if (widget.room.mode == 'live')
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                const Icon(Icons.timer, size: 16, color: Color(0xFFEF5350)),
                const SizedBox(width: 6),
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: timerPercent.clamp(0.0, 1.0),
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(
                      _timeLeft <= 5 ? const Color(0xFFEF5350)
                          : const Color(0xFF10B981),
                    ),
                    minHeight: 8,
                  ),
                )),
                const SizedBox(width: 8),
                Text('${_timeLeft}s', style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: _timeLeft <= 5
                        ? const Color(0xFFEF5350) : const Color(0xFF374151))),
              ]),
            ),

          // Question and options
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              // Question card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Text(
                  question['question'] as String? ?? '',
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A2E), height: 1.5),
                ),
              ),
              const SizedBox(height: 16),

              // Options
              ...List.generate(options.length, (i) {
                Color bg = Colors.white;
                Color border = Colors.grey.shade300;
                Color text = const Color(0xFF374151);

                if (_answered) {
                  if (i == correctIndex) {
                    bg = const Color(0xFFE8F5E9);
                    border = const Color(0xFF10B981);
                    text = const Color(0xFF065F46);
                  } else if (i == _selectedAnswer && i != correctIndex) {
                    bg = const Color(0xFFFFEBEE);
                    border = const Color(0xFFEF5350);
                    text = const Color(0xFFC62828);
                  }
                } else if (_selectedAnswer == i) {
                  bg = _primary.withOpacity(0.08);
                  border = _primary;
                  text = _primary;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: _answered ? null : () => _submitAnswer(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border, width: 1.5),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 4)],
                      ),
                      child: Row(children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: border.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Center(child: Text(
                            ['A', 'B', 'C', 'D'][i],
                            style: GoogleFonts.poppins(
                                fontSize: 12, fontWeight: FontWeight.w700,
                                color: border),
                          )),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(options[i],
                            style: GoogleFonts.poppins(
                                fontSize: 13, color: text,
                                fontWeight: FontWeight.w500))),
                        if (_answered && i == correctIndex)
                          const Icon(Icons.check_circle,
                              color: Color(0xFF10B981), size: 20),
                        if (_answered && i == _selectedAnswer && i != correctIndex)
                          const Icon(Icons.cancel,
                              color: Color(0xFFEF5350), size: 20),
                      ]),
                    ),
                  ),
                );
              }),

              // Explanation (shown after answering)
              if (_answered && question['explanation'] != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFFFC107).withOpacity(0.5)),
                  ),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('💡', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                            question['explanation'] as String? ?? '',
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: const Color(0xFF92400E),
                                height: 1.4))),
                      ]),
                ),
              ],

              const SizedBox(height: 40),
            ]),
          )),
        ]),
      ),
    );
  }
}