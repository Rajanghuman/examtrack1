import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:examtrack/services/progress_service.dart';

// ============================================================
// Progress UI Components
//
// 1. ProgressWidgets.showXPToast() — floating +XP notification
// 2. ProgressWidgets.showAchievementUnlock() — achievement popup
// 3. ProgressCard — home screen dashboard card
// 4. ProfileProgressSection — full detail for profile screen
// ============================================================

class ProgressWidgets {
  // ── XP Toast ───────────────────────────────────────────────
  // Shows a brief floating "+30 XP" message at the top of the
  // screen whenever XP is earned. Non-blocking, auto-dismisses.
  static void showXPToast(
      BuildContext context,
      int xpAmount, {
        String? action,
        bool didRankUp = false,
        String? newRank,
      }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(builder: (_) => _XPToast(
      xpAmount: xpAmount,
      action: action,
      didRankUp: didRankUp,
      newRank: newRank,
      onDismiss: () => entry.remove(),
    ));

    overlay.insert(entry);
  }

  // ── Achievement Unlock Popup ────────────────────────────────
  // Shows a modal bottom sheet when a new achievement is unlocked.
  static void showAchievementUnlock(
      BuildContext context,
      Map<String, dynamic> achievement,
      ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AchievementUnlockSheet(achievement: achievement),
    );
  }

  // ── Handle a ProgressUpdateResult ──────────────────────────
  // Convenience method — call this after any awardXP() call to
  // show all the right notifications automatically.
  static void handleResult(BuildContext context, ProgressUpdateResult result) {
    if (!result.hasUpdate) return;

    if (result.xpAwarded > 0) {
      showXPToast(context, result.xpAwarded,
          didRankUp: result.didRankUp, newRank: result.newRank);
    }

    for (final achievement in result.newlyUnlockedAchievements) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (context.mounted) showAchievementUnlock(context, achievement);
      });
    }
  }
}

// ── XP Toast Widget ─────────────────────────────────────────
class _XPToast extends StatefulWidget {
  final int xpAmount;
  final String? action;
  final bool didRankUp;
  final String? newRank;
  final VoidCallback onDismiss;

  const _XPToast({
    required this.xpAmount,
    required this.onDismiss,
    this.action,
    this.didRankUp = false,
    this.newRank,
  });

  @override
  State<_XPToast> createState() => _XPToastState();
}

class _XPToastState extends State<_XPToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _opacity = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.4)));
    _slide = Tween(begin: const Offset(0, -0.5), end: Offset.zero).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _ctrl.forward();

    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        _ctrl.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      left: 0, right: 0,
      child: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: SlideTransition(
            position: _slide,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: widget.didRankUp
                      ? const Color(0xFF7B1FA2)
                      : const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 12, offset: const Offset(0, 4),
                  )],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(widget.didRankUp ? '🎖️' : '⚡',
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      widget.didRankUp
                          ? 'RANK UP! ${widget.newRank}'
                          : '+${widget.xpAmount} XP',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 13,
                          fontWeight: FontWeight.w700),
                    ),
                    if (widget.action != null)
                      Text(_actionLabel(widget.action!),
                          style: GoogleFonts.poppins(
                              color: Colors.white60, fontSize: 10)),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'daily_open': return 'Daily bonus';
      case 'pyq_answered': return 'PYQ answered';
      case 'mock_test_completed': return 'Mock test done';
      case 'job_applied': return 'Job applied';
      case 'chapter_read': return 'Chapter read';
      case 'streak_milestone': return 'Streak milestone!';
      default: return '';
    }
  }
}

// ── Achievement Unlock Sheet ────────────────────────────────
class _AchievementUnlockSheet extends StatelessWidget {
  final Map<String, dynamic> achievement;
  const _AchievementUnlockSheet({required this.achievement});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFFFC107), width: 2),
          ),
          child: Center(child: Text(achievement['icon'] ?? '🏆',
              style: const TextStyle(fontSize: 36))),
        ),
        const SizedBox(height: 16),
        Text('Achievement Unlocked!', style: GoogleFonts.poppins(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: const Color(0xFFF59E0B), letterSpacing: 1.2)),
        const SizedBox(height: 6),
        Text(achievement['title'] ?? '', style: GoogleFonts.poppins(
            fontSize: 20, fontWeight: FontWeight.w800,
            color: const Color(0xFF1A1A2E))),
        const SizedBox(height: 4),
        Text(achievement['desc'] ?? '', textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade500)),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A1A2E),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text('Keep Going! 💪', style: GoogleFonts.poppins(
              color: Colors.white, fontWeight: FontWeight.w600)),
        )),
      ]),
    );
  }
}

// ── My XP & Achievements Button ────────────────────────────
// Compact button shown on home and profile screens. Tapping
// opens the full XP dashboard as a bottom sheet.
class XPButton extends StatelessWidget {
  final Map<String, dynamic> progress;

  const XPButton({super.key, required this.progress});

  void _showDashboard(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => XPDashboardSheet(progress: progress),
    );
  }

  @override
  Widget build(BuildContext context) {
    final xp = (progress['xp'] as num?)?.toInt() ?? 0;
    final streak = (progress['streak'] as num?)?.toInt() ?? 0;
    final rankData = ProgressService.rankForXP(xp);
    final rankColor = Color(rankData['color'] as int);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        onTap: () => _showDashboard(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: rankColor.withOpacity(0.3)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
          ),
          child: Row(children: [
            Text(rankData['icon'] as String, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${rankData['name']} • $xp XP',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A2E))),
              Text('🔥 $streak day streak',
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: rankColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('⚡', style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                Text('My XP & Achievements',
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600,
                        color: rankColor)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── XP Dashboard Bottom Sheet ──────────────────────────────
// Full dashboard shown when user taps the XP button.
class XPDashboardSheet extends StatelessWidget {
  final Map<String, dynamic> progress;
  const XPDashboardSheet({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final xp = (progress['xp'] as num?)?.toInt() ?? 0;
    final streak = (progress['streak'] as num?)?.toInt() ?? 0;
    final longestStreak = (progress['longestStreak'] as num?)?.toInt() ?? 0;
    final rankData = ProgressService.rankForXP(xp);
    final nextRank = ProgressService.nextRankForXP(xp);
    final progressPct = ProgressService.rankProgressPercent(xp);
    final rankColor = Color(rankData['color'] as int);
    final achievements = (progress['achievements'] as List?) ?? [];

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFFF5F7FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        // Handle
        const SizedBox(height: 12),
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        // Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Text('⚡ My XP & Achievements', style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF1A1A2E))),
            const Spacer(),
            GestureDetector(onTap: () => Navigator.pop(context),
                child: Icon(Icons.close, color: Colors.grey.shade400)),
          ]),
        ),
        const SizedBox(height: 16),
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Rank card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [rankColor, rankColor.withOpacity(0.7)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: rankColor.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Column(children: [
              Row(children: [
                Text(rankData['icon'] as String, style: const TextStyle(fontSize: 40)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(rankData['name'] as String, style: GoogleFonts.poppins(
                      color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                  Text('$xp XP earned', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                ])),
              ]),
              if (nextRank != null) ...[
                const SizedBox(height: 14),
                Row(children: [
                  Text('Progress to ${nextRank['name']}',
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
                  const Spacer(),
                  Text('${(progressPct * 100).round()}%',
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 6),
                ClipRRect(borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: progressPct,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation(Colors.white), minHeight: 8)),
              ] else
                Text('👑 Maximum Rank Achieved!', style: GoogleFonts.poppins(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(height: 16),
          // Stats row
          Row(children: [
            _statCard('🔥', '$streak', 'Day Streak', const Color(0xFFEF5350)),
            const SizedBox(width: 10),
            _statCard('📈', '$longestStreak', 'Best Streak', const Color(0xFF1565C0)),
            const SizedBox(width: 10),
            _statCard('🏅', '${achievements.length}', 'Achievements', const Color(0xFFF59E0B)),
          ]),
          // How XP works info card
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('How to earn XP', style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E))),
              const SizedBox(height: 10),
              ...[
                ['⚡', 'Daily app open', '+5 XP'],
                ['📖', 'Read a chapter', '+15 XP'],
                ['❓', 'Answer a PYQ', '+10 XP'],
                ['📝', 'Complete mock test', '+50 XP'],
                ['📨', 'Apply for a job', '+30 XP'],
                ['🔥', 'Daily streak bonus', '+10 XP'],
                ['🏅', 'Unlock achievement', '+75 XP'],
                ['🎯', 'Streak milestone (7 days)', '+100 XP'],
              ].map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Text(item[0], style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item[1], style: GoogleFonts.poppins(
                      fontSize: 12, color: const Color(0xFF374151)))),
                  Text(item[2], style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1565C0))),
                ]),
              )),
            ]),
          ),
          // Achievements
          if (achievements.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Achievements', style: GoogleFonts.poppins(
                fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E))),
            const SizedBox(height: 10),
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: achievements.length,
                itemBuilder: (_, i) {
                  final a = achievements[i] as Map;
                  final def = ProgressService.achievementDefs.firstWhere(
                          (d) => d['id'] == a['id'], orElse: () => {'title': a['title'] ?? '', 'icon': '🏅'});
                  return Container(
                    width: 80, margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFFC107).withOpacity(0.4)),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(def['icon'] as String? ?? '🏅', style: const TextStyle(fontSize: 26)),
                      const SizedBox(height: 4),
                      Text(def['title'] as String? ?? '', textAlign: TextAlign.center,
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w600,
                              color: const Color(0xFF374151))),
                    ]),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 24),
        ]))),
      ]),
    );
  }

  Widget _statCard(String icon, String value, String label, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey.shade500)),
      ]),
    ));
  }
}

// ── Home Screen Progress Card (REMOVED) ────────────────────
// Replaced by XPButton above. Kept as a stub to avoid breaking
// any existing references during the transition.
class ProgressCard extends StatelessWidget {
  final Map<String, dynamic> progress;
  final VoidCallback? onTap;
  const ProgressCard({super.key, required this.progress, this.onTap});

  @override
  Widget build(BuildContext context) => XPButton(progress: progress);
}

// ── Profile Progress Section ────────────────────────────────
// Full-detail progress view for the profile screen showing
// rank, XP, streak, achievements list, and exam history.
class ProfileProgressSection extends StatelessWidget {
  final Map<String, dynamic> progress;

  const ProfileProgressSection({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final xp = (progress['xp'] as num?)?.toInt() ?? 0;
    final streak = (progress['streak'] as num?)?.toInt() ?? 0;
    final longestStreak = (progress['longestStreak'] as num?)?.toInt() ?? 0;
    final rankData = ProgressService.rankForXP(xp);
    final nextRank = ProgressService.nextRankForXP(xp);
    final progressPct = ProgressService.rankProgressPercent(xp);
    final rankColor = Color(rankData['color'] as int);
    final achievements = (progress['achievements'] as List?) ?? [];
    final examHistory = (progress['examHistory'] as List?) ?? [];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Rank card ───────────────────────────────────────────
      Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [rankColor, rankColor.withOpacity(0.7)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: rankColor.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(children: [
          Row(children: [
            Text(rankData['icon'] as String, style: const TextStyle(fontSize: 40)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(rankData['name'] as String, style: GoogleFonts.poppins(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              Text('$xp XP earned', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
            ])),
          ]),
          if (nextRank != null) ...[
            const SizedBox(height: 14),
            Row(children: [
              Text('Progress to ${nextRank['name'] as String}',
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
              const Spacer(),
              Text('${(progressPct * 100).round()}%',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressPct,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
                minHeight: 8,
              ),
            ),
          ],
        ]),
      ),

      // ── Stats row ───────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          _statCard('🔥', '$streak', 'Day Streak', const Color(0xFFEF5350)),
          const SizedBox(width: 10),
          _statCard('📈', '$longestStreak', 'Best Streak', const Color(0xFF1565C0)),
          const SizedBox(width: 10),
          _statCard('🏅', '${achievements.length}', 'Achievements', const Color(0xFFF59E0B)),
        ]),
      ),

      // ── Achievements ────────────────────────────────────────
      if (achievements.isNotEmpty) ...[
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Achievements', style: GoogleFonts.poppins(
              fontSize: 16, fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1A2E))),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: achievements.length,
            itemBuilder: (_, i) {
              final a = achievements[i] as Map;
              final def = ProgressService.achievementDefs.firstWhere(
                    (d) => d['id'] == a['id'],
                orElse: () => {'title': a['title'] ?? '', 'icon': '🏅'},
              );
              return Container(
                width: 75, margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFC107).withOpacity(0.4)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(def['icon'] as String? ?? '🏅',
                      style: const TextStyle(fontSize: 26)),
                  const SizedBox(height: 4),
                  Text(def['title'] as String? ?? '',
                      textAlign: TextAlign.center,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w600,
                          color: const Color(0xFF374151))),
                ]),
              );
            },
          ),
        ),
      ],

      // ── Exam history ─────────────────────────────────────────
      if (examHistory.isNotEmpty) ...[
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Exam History', style: GoogleFonts.poppins(
              fontSize: 16, fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1A2E))),
        ),
        const SizedBox(height: 10),
        ...examHistory.reversed.take(5).map((e) {
          final exam = e as Map;
          final status = exam['status'] as String? ?? 'applied';
          final statusColor = _statusColor(status);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
            ),
            child: Row(children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(exam['examName'] as String? ?? '',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A2E)))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(status.toUpperCase(), style: GoogleFonts.poppins(
                    fontSize: 9, fontWeight: FontWeight.w700, color: statusColor)),
              ),
            ]),
          );
        }),
      ],

      const SizedBox(height: 24),
    ]);
  }

  Widget _statCard(String icon, String value, String label, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.poppins(
            fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey.shade500)),
      ]),
    ));
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'passed': return const Color(0xFF10B981);
      case 'failed': return const Color(0xFFEF4444);
      case 'appeared': return const Color(0xFF1565C0);
      default: return const Color(0xFFF59E0B); // applied
    }
  }
}