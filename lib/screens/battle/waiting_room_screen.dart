import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:examtrack/services/battle_service.dart';
import 'package:examtrack/screens/battle/live_battle_screen.dart';

class WaitingRoomScreen extends StatefulWidget {
  final BattleRoom room;
  const WaitingRoomScreen({super.key, required this.room});

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  late StreamSubscription<BattleRoom> _roomSub;
  BattleRoom? _currentRoom;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _currentRoom = widget.room;
    _roomSub = BattleService.watchRoom(widget.room.roomCode).listen(
          (room) {
        if (!mounted) return;
        setState(() => _currentRoom = room);

        // Friend joined — navigate to battle
        if (!_navigating &&
            (room.status == 'countdown' || room.status == 'active') &&
            room.p2 != null) {
          _navigating = true;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => LiveBattleScreen(room: room),
            ),
          );
        }
      },
      onError: (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Connection error: $e',
                style: GoogleFonts.poppins(fontSize: 12)),
            backgroundColor: const Color(0xFFEF4444),
          ));
        }
      },
    );
  }

  @override
  void dispose() {
    _roomSub.cancel();
    super.dispose();
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.room.roomCode));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Room code copied!',
          style: GoogleFonts.poppins(fontSize: 12)),
      backgroundColor: const Color(0xFF10B981),
      duration: const Duration(seconds: 1),
    ));
  }

  void _shareCode() {
    Share.share(
      '⚔️ I\'m challenging you to a 1v1 Quiz Battle on ExamTrack!\n\n'
          'Topic: ${widget.room.topic}\n'
          'Questions: ${widget.room.questionCount}\n\n'
          'Join with room code: ${widget.room.roomCode}\n\n'
          'Download ExamTrack and let\'s battle! 🎯',
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = _currentRoom ?? widget.room;
    final friendJoined = room.p2 != null;

    return PopScope(
      canPop: !friendJoined,
      onPopInvoked: (didPop) {
        if (!didPop && friendJoined) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Battle is starting! You can\'t leave now.',
                style: GoogleFonts.poppins(fontSize: 12)),
            backgroundColor: const Color(0xFFEF4444),
          ));
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Column(children: [
          // Header
          Container(
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
            child: Row(children: [
              if (!friendJoined)
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white),
                )
              else
                const SizedBox(width: 24),
              const SizedBox(width: 12),
              Text('Battle Room', style: GoogleFonts.poppins(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            ]),
          ),

          Expanded(child: Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [

              // Animated waiting indicator / friend joined
              if (!friendJoined) ...[
                const _PulsingIcon(),
                const SizedBox(height: 24),
                Text('Waiting for opponent...', style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A2E))),
                const SizedBox(height: 8),
                Text('Share the room code with your friend',
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: Colors.grey.shade500)),
              ] else ...[
                const Text('🎉', style: TextStyle(fontSize: 60)),
                const SizedBox(height: 16),
                Text('${room.p2!['name']} joined!', style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.w800,
                    color: const Color(0xFF10B981))),
                const SizedBox(height: 8),
                Text('Get ready to battle! 🔥', style: GoogleFonts.poppins(
                    fontSize: 14, color: Colors.grey.shade500)),
              ],

              const SizedBox(height: 40),

              // Room code display
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 16)],
                ),
                child: Column(children: [
                  Text('Room Code', style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600, letterSpacing: 1.5)),
                  const SizedBox(height: 10),
                  // Large digit display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: widget.room.roomCode.split('').map((digit) =>
                        Container(
                          width: 42, height: 52,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1565C0).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFF1565C0).withOpacity(0.2)),
                          ),
                          child: Center(child: Text(digit,
                              style: GoogleFonts.poppins(
                                  fontSize: 22, fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1565C0)))),
                        ),
                    ).toList(),
                  ),
                  const SizedBox(height: 16),
                  // Room info chips
                  Wrap(spacing: 8, children: [
                    _chip(room.topic),
                    _chip('${room.questionCount} Qs'),
                    if (room.mode == 'live') _chip('${room.timerSeconds}s/Q'),
                    _chip(room.mode == 'live' ? '⚡ Live' : '📩 Challenge'),
                  ]),
                ]),
              ),

              const SizedBox(height: 24),

              // Action buttons
              if (!friendJoined) ...[
                Row(children: [
                  Expanded(child: OutlinedButton.icon(
                    onPressed: _copyCode,
                    icon: const Icon(Icons.copy, size: 16),
                    label: Text('Copy Code', style: GoogleFonts.poppins(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1565C0),
                      side: const BorderSide(color: Color(0xFF1565C0)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: ElevatedButton.icon(
                    onPressed: _shareCode,
                    icon: const Icon(Icons.share, size: 16, color: Colors.white),
                    label: Text('Share', style: GoogleFonts.poppins(
                        color: Colors.white, fontSize: 13,
                        fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7B1FA2),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  )),
                ]),
              ],
            ]),
          ))),
        ]),
      ),
    );
  }

  Widget _chip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label, style: GoogleFonts.poppins(
        fontSize: 11, fontWeight: FontWeight.w600,
        color: Colors.grey.shade600)),
  );
}

// Pulsing waiting animation
class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon();

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _anim,
      child: Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFF1565C0).withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(
              color: const Color(0xFF1565C0).withOpacity(0.3), width: 2),
        ),
        child: const Center(
          child: Text('⚔️', style: TextStyle(fontSize: 36)),
        ),
      ),
    );
  }
}