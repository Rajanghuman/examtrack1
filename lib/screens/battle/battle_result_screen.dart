import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:examtrack/services/battle_service.dart';

class BattleResultScreen extends StatelessWidget {
  final BattleRoom room;
  const BattleResultScreen({super.key, required this.room});

  static const Color _primary = Color(0xFF1565C0);
  static const Color _accent = Color(0xFF7B1FA2);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final myKey = BattleService.getMyPlayerKey(room);
    final opponentKey = myKey == 'p1' ? 'p2' : 'p1';

    final me = room.players[myKey] as Map?;
    final opponent = room.players[opponentKey] as Map?;

    final myScore = me != null ? (me['score'] as int? ?? 0) : 0;
    final opponentScore = opponent != null
        ? (opponent['score'] as int? ?? 0) : 0;
    final myName = me != null ? (me['name'] as String? ?? 'You') : 'You';
    final opponentName = opponent != null
        ? (opponent['name'] as String? ?? 'Opponent') : 'Opponent';

    final isWinner = room.winnerId == uid;
    final isDraw = room.winnerId == 'draw';

    String resultEmoji;
    String resultText;
    String subText;
    Color resultColor;
    int xpEarned;

    if (isDraw) {
      resultEmoji = '🤝';
      resultText = 'It\'s a Draw!';
      subText = 'Well played by both!';
      resultColor = const Color(0xFFF59E0B);
      xpEarned = BattleService.xpDraw;
    } else if (isWinner) {
      resultEmoji = '🏆';
      resultText = 'You Won!';
      subText = 'Outstanding performance!';
      resultColor = const Color(0xFF10B981);
      xpEarned = BattleService.xpWin;
    } else {
      resultEmoji = '😔';
      resultText = 'You Lost';
      subText = 'Better luck next time!';
      resultColor = const Color(0xFFEF5350);
      xpEarned = BattleService.xpLose;
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Column(children: [
          // Result header
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [resultColor, resultColor.withOpacity(0.7)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              left: 16, right: 16, bottom: 30,
            ),
            child: Column(children: [
              Text(resultEmoji, style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 12),
              Text(resultText, style: GoogleFonts.poppins(
                  color: Colors.white, fontSize: 28,
                  fontWeight: FontWeight.w800)),
              Text(subText, style: GoogleFonts.poppins(
                  color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 12),
              // XP earned badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('⚡ +$xpEarned XP earned',
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          ),

          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              const SizedBox(height: 8),

              // Score comparison card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Column(children: [
                  Text('Final Score', style: GoogleFonts.poppins(
                      fontSize: 13, color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600, letterSpacing: 1)),
                  const SizedBox(height: 16),
                  Row(children: [
                    // My score
                    Expanded(child: Column(children: [
                      Text(myName, style: GoogleFonts.poppins(
                          fontSize: 13, color: Colors.grey.shade500),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Text('$myScore', style: GoogleFonts.poppins(
                          fontSize: 42, fontWeight: FontWeight.w900,
                          color: isWinner
                              ? const Color(0xFF10B981) : const Color(0xFF1A1A2E))),
                      Text('correct', style: GoogleFonts.poppins(
                          fontSize: 11, color: Colors.grey.shade400)),
                    ])),
                    // Divider
                    Container(
                      height: 60, width: 1,
                      color: Colors.grey.shade200,
                    ),
                    // Opponent score
                    Expanded(child: Column(children: [
                      Text(opponentName, style: GoogleFonts.poppins(
                          fontSize: 13, color: Colors.grey.shade500),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Text('$opponentScore', style: GoogleFonts.poppins(
                          fontSize: 42, fontWeight: FontWeight.w900,
                          color: (!isWinner && !isDraw)
                              ? const Color(0xFF10B981) : const Color(0xFF1A1A2E))),
                      Text('correct', style: GoogleFonts.poppins(
                          fontSize: 11, color: Colors.grey.shade400)),
                    ])),
                  ]),
                  const SizedBox(height: 16),
                  // Topic + question count
                  Wrap(spacing: 8, children: [
                    _chip(room.topic),
                    _chip('${room.questionCount} Questions'),
                    _chip(room.mode == 'live' ? '⚡ Live' : '📩 Challenge'),
                  ]),
                ]),
              ),

              const SizedBox(height: 20),

              // Action buttons
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context, '/home', (route) => false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Back to Home', style: GoogleFonts.poppins(
                    color: Colors.white, fontSize: 15,
                    fontWeight: FontWeight.w700)),
              )),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: OutlinedButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context, '/battle', (route) => false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accent,
                  side: const BorderSide(color: _accent),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Play Again ⚔️', style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w700,
                    color: _accent)),
              )),
              const SizedBox(height: 40),
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _chip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label, style: GoogleFonts.poppins(
        fontSize: 11, fontWeight: FontWeight.w600,
        color: Colors.grey.shade600)),
  );
}