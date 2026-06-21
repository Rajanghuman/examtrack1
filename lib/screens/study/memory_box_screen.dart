import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/memory_box_service.dart';

class MemoryBoxScreen extends StatefulWidget {
  const MemoryBoxScreen({super.key});

  @override
  State<MemoryBoxScreen> createState() => _MemoryBoxScreenState();
}

class _MemoryBoxScreenState extends State<MemoryBoxScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _allQuestions = [];
  List<Map<String, dynamic>> _dueQuestions = [];
  List<MapEntry<String, int>> _topicBreakdown = [];

  // Revision quiz state
  bool _inRevision = false;
  int _revisionIndex = 0;
  String? _selectedAns;
  bool _showExp = false;
  int _revisionCorrect = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final all = await MemoryBoxService.getAllQuestions();
    final due = await MemoryBoxService.getDueQuestions();
    final topics = await MemoryBoxService.getTopicBreakdown();
    if (!mounted) return;
    setState(() {
      _allQuestions = all;
      _dueQuestions = due;
      _topicBreakdown = topics;
      _loading = false;
    });
  }

  void _startRevision({String? topicFilter}) {
    final source = topicFilter == null
        ? _dueQuestions
        : _allQuestions.where((q) => q['topic'] == topicFilter).toList();

    if (source.isEmpty) return;

    setState(() {
      _inRevision = true;
      _revisionIndex = 0;
      _revisionCorrect = 0;
      _selectedAns = null;
      _showExp = false;
      _dueQuestions = source; // reuse as the active revision set
    });
  }

  void _exitRevision() {
    setState(() {
      _inRevision = false;
      _selectedAns = null;
      _showExp = false;
    });
    _loadData();
  }

  Color _diffColor(int wrongCount) {
    if (wrongCount >= 3) return const Color(0xFFEF4444);
    if (wrongCount == 2) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0)))
            : (_inRevision ? _buildRevisionQuiz() : _buildMainView()),
      ),
    );
  }

  // ── MAIN VIEW ──────────────────────────────────────────────
  Widget _buildMainView() {
    return Column(
      children: [
        _header(),
        Expanded(
          child: _allQuestions.isEmpty
              ? _emptyState()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _summaryCard(),
                    const SizedBox(height: 20),
                    if (_dueQuestions.isNotEmpty) _dueButton(),
                    const SizedBox(height: 20),
                    Text('Your Weak Topics',
                        style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A1A2E))),
                    const SizedBox(height: 10),
                    ..._topicBreakdown.map(_topicCard),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Memory Box',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w700)),
              Text('Master what you got wrong',
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline_rounded,
                  size: 44, color: Color(0xFF10B981)),
            ),
            const SizedBox(height: 20),
            Text('Your Memory Box is empty',
                style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A2E))),
            const SizedBox(height: 8),
            Text(
              'Take a quiz or mock test. Questions you get wrong will land here automatically, so you can revise exactly what you need to.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: Colors.grey.shade500, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_allQuestions.length}',
                    style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1565C0))),
                Text('questions need revision',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Container(width: 1, height: 40, color: Colors.grey.shade200),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_dueQuestions.length}',
                  style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFEF4444))),
              Text('due today',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey.shade500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dueButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _startRevision(),
        icon: const Icon(Icons.refresh_rounded, color: Colors.white),
        label: Text('Start Revision — ${_dueQuestions.length} Questions',
            style: GoogleFonts.poppins(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEF4444),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _topicCard(MapEntry<String, int> entry) {
    final topic = entry.key;
    final count = entry.value;
    final color = _diffColor(count >= 3 ? 3 : count);

    return GestureDetector(
      onTap: () => _startRevision(topicFilter: topic),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 36,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(topic,
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A1A2E))),
                  Text('$count question${count == 1 ? '' : 's'} to revise',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  // ── REVISION QUIZ VIEW ─────────────────────────────────────
  Widget _buildRevisionQuiz() {
    if (_revisionIndex >= _dueQuestions.length) {
      return _revisionResult();
    }

    final q = _dueQuestions[_revisionIndex];
    final options = (q['options'] as List).cast<String>();
    final correctIndex = q['correctIndex'] as int;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _exitRevision,
                child: const Icon(Icons.close_rounded, color: Color(0xFF374151)),
              ),
              const SizedBox(width: 10),
              Text('Revision ${_revisionIndex + 1}/${_dueQuestions.length}',
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1565C0))),
              const Spacer(),
              Text('Score: $_revisionCorrect',
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF10B981))),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: (_revisionIndex + 1) / _dueQuestions.length,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation(Color(0xFF1565C0)),
            borderRadius: BorderRadius.circular(4),
            minHeight: 5,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(q['topic'] as String? ?? 'General',
                style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1565C0))),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)
              ],
            ),
            child: Text(q['question'] as String,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1A2E),
                    height: 1.5)),
          ),
          const SizedBox(height: 12),
          ...options.asMap().entries.map((e) {
            final i = e.key;
            final opt = e.value;
            final lbl = ['A', 'B', 'C', 'D'][i];

            Color bg = Colors.white;
            Color border = Colors.grey.shade200;
            Color txt = const Color(0xFF374151);
            Color lblBg = const Color(0xFF1565C0);

            if (_selectedAns != null) {
              if (i == correctIndex) {
                bg = const Color(0xFF10B981).withOpacity(0.1);
                border = const Color(0xFF10B981);
                txt = const Color(0xFF10B981);
                lblBg = const Color(0xFF10B981);
              } else if (_selectedAns == lbl) {
                bg = const Color(0xFFEF4444).withOpacity(0.1);
                border = const Color(0xFFEF4444);
                txt = const Color(0xFFEF4444);
                lblBg = const Color(0xFFEF4444);
              }
            }

            return GestureDetector(
              onTap: _selectedAns == null
                  ? () async {
                      final isCorrect = i == correctIndex;
                      setState(() {
                        _selectedAns = lbl;
                        _showExp = true;
                        if (isCorrect) _revisionCorrect++;
                      });
                      final qid = q['id'] as String;
                      if (isCorrect) {
                        await MemoryBoxService.markCorrectInRevision(qid);
                      } else {
                        await MemoryBoxService.markWrongInRevision(qid);
                      }
                    }
                  : null,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                          color: lblBg, borderRadius: BorderRadius.circular(7)),
                      child: Center(
                        child: Text(lbl,
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(opt,
                            style: GoogleFonts.poppins(fontSize: 13, color: txt))),
                  ],
                ),
              ),
            );
          }),
          if (_showExp) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lightbulb_outline,
                          color: Color(0xFF1565C0), size: 15),
                      const SizedBox(width: 5),
                      Text('Explanation',
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1565C0))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(q['explanation'] as String? ?? '',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: const Color(0xFF374151), height: 1.4)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _revisionIndex++;
                    _selectedAns = null;
                    _showExp = false;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  _revisionIndex < _dueQuestions.length - 1
                      ? 'Next Question →'
                      : 'Finish Revision',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _revisionResult() {
    final total = _dueQuestions.length;
    final pct = total > 0 ? (_revisionCorrect / total * 100).round() : 0;
    final color = pct >= 70
        ? const Color(0xFF10B981)
        : pct >= 50
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 3),
              ),
              child: Center(
                child: Text('$pct%',
                    style: GoogleFonts.poppins(
                        fontSize: 26, fontWeight: FontWeight.w800, color: color)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Revision Complete!',
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A2E))),
            const SizedBox(height: 6),
            Text(
              '$_revisionCorrect out of $total correct.\nQuestions you got right twice in a row leave your Memory Box for good.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: Colors.grey.shade500, height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _exitRevision,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Back to Memory Box',
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
