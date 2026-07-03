import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:examtrack/services/battle_service.dart';
import 'package:examtrack/screens/battle/live_battle_screen.dart';

class JoinBattleScreen extends StatefulWidget {
  const JoinBattleScreen({super.key});

  @override
  State<JoinBattleScreen> createState() => _JoinBattleScreenState();
}

class _JoinBattleScreenState extends State<JoinBattleScreen> {
  final _codeController = TextEditingController();
  bool _isJoining = false;
  String _error = '';

  static const Color _primary = Color(0xFF1565C0);

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _joinRoom() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Please enter a valid 6-digit room code');
      return;
    }

    setState(() { _isJoining = true; _error = ''; });

    try {
      final room = await BattleService.joinRoom(code);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LiveBattleScreen(room: room)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isJoining = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(children: [
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
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text('Join Battle', style: GoogleFonts.poppins(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          ]),
        ),

        Expanded(child: Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('🔑', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 20),
            Text('Enter Room Code', style: GoogleFonts.poppins(
                fontSize: 22, fontWeight: FontWeight.w800,
                color: const Color(0xFF1A1A2E))),
            const SizedBox(height: 8),
            Text('Ask your friend for their 6-digit room code',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: Colors.grey.shade500)),
            const SizedBox(height: 32),

            // Code input
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.poppins(
                  fontSize: 28, fontWeight: FontWeight.w800,
                  letterSpacing: 12, color: _primary),
              decoration: InputDecoration(
                counterText: '',
                hintText: '000000',
                hintStyle: GoogleFonts.poppins(
                    fontSize: 28, letterSpacing: 12,
                    color: Colors.grey.shade300, fontWeight: FontWeight.w800),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 20),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _primary, width: 2)),
              ),
              onChanged: (v) {
                if (v.length == 6) _joinRoom();
              },
            ),

            if (_error.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFEF5350)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline,
                      color: Color(0xFFD32F2F), size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error, style: GoogleFonts.poppins(
                      fontSize: 12, color: const Color(0xFFC62828)))),
                ]),
              ),
            ],

            const SizedBox(height: 24),

            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: _isJoining ? null : _joinRoom,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _isJoining
                  ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : Text('Join Battle ⚔️', style: GoogleFonts.poppins(
                  color: Colors.white, fontSize: 15,
                  fontWeight: FontWeight.w700)),
            )),
          ]),
        ))),
      ]),
    );
  }
}