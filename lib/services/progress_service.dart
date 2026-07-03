import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ============================================================
// ProgressService — the single source of truth for all
// gamification state (XP, rank, streak, achievements, exam
// history). All game logic lives here; UI just calls these
// static methods and reads the resulting data.
//
// Data lives in: users/{userId}/progress (one doc per user).
// All writes are batched where possible to minimize Firestore
// round-trips.
// ============================================================

class ProgressService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // ── Rank ladder ────────────────────────────────────────────
  static const List<Map<String, dynamic>> ranks = [
    {'name': 'Bronze',   'minXP': 0,      'color': 0xFFCD7F32, 'icon': '🥉'},
    {'name': 'Silver',   'minXP': 500,    'color': 0xFF9E9E9E, 'icon': '🥈'},
    {'name': 'Gold',     'minXP': 1500,   'color': 0xFFFFC107, 'icon': '🥇'},
    {'name': 'Platinum', 'minXP': 3500,   'color': 0xFF00BCD4, 'icon': '💠'},
    {'name': 'Diamond',  'minXP': 7000,   'color': 0xFF1565C0, 'icon': '💎'},
    {'name': 'Legend',   'minXP': 12000,  'color': 0xFF7B1FA2, 'icon': '👑'},
  ];

  // ── XP earning actions ─────────────────────────────────────
  static const int xpDailyOpen       = 5;
  static const int xpPYQAnswered     = 10;
  static const int xpMockCompleted   = 50;
  static const int xpJobApplied      = 30;
  static const int xpStreakMilestone = 100;
  static const int xpAchievement     = 75;
  static const int xpChapterRead     = 15;
  static const int xpStreakDaily     = 10;

  // ── Achievement definitions ────────────────────────────────
  static const List<Map<String, dynamic>> achievementDefs = [
    {'id': 'first_open',       'title': 'Welcome Aboard!',   'desc': 'Open the app for the first time',     'icon': '👋', 'xp': 0},
    {'id': 'first_mock',       'title': 'First Drill',        'desc': 'Complete your first mock test',        'icon': '📝', 'xp': xpAchievement},
    {'id': 'first_apply',      'title': 'First Application',  'desc': 'Apply for your first job',             'icon': '📨', 'xp': xpAchievement},
    {'id': 'streak_7',         'title': 'Week Warrior',       'desc': 'Maintain a 7-day streak',              'icon': '🔥', 'xp': xpStreakMilestone},
    {'id': 'streak_30',        'title': 'Monthly Grind',      'desc': 'Maintain a 30-day streak',             'icon': '💪', 'xp': xpStreakMilestone},
    {'id': 'mock_5',           'title': 'Drill Sergeant',     'desc': 'Complete 5 mock tests',                'icon': '🎖️', 'xp': xpAchievement},
    {'id': 'perfect_mock',     'title': 'Full Marks',         'desc': 'Score 100% on any mock test',          'icon': '🏆', 'xp': xpAchievement},
    {'id': 'jobs_10',          'title': 'Job Hunter',         'desc': 'Apply for 10 jobs',                    'icon': '🎯', 'xp': xpAchievement},
    {'id': 'chapters_10',      'title': 'Bookworm',           'desc': 'Read 10 study chapters',               'icon': '📚', 'xp': xpAchievement},
    {'id': 'rank_up_silver',   'title': 'Gone Silver!',    'desc': 'Reach Silver rank',               'icon': '🥈', 'xp': xpAchievement},
    {'id': 'rank_up_gold',     'title': 'Gone Gold!',      'desc': 'Reach Gold rank',                 'icon': '🥇', 'xp': xpAchievement},
    {'id': 'rank_up_platinum', 'title': 'Gone Platinum!',  'desc': 'Reach Platinum rank',             'icon': '💠', 'xp': xpAchievement},
  ];

  // ── Helpers ────────────────────────────────────────────────
  static String? get _uid => _auth.currentUser?.uid;

  static DocumentReference? get _progressDoc {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('progress').doc('data');
  }

  static Map<String, dynamic> rankForXP(int xp) {
    Map<String, dynamic> current = ranks.first;
    for (final rank in ranks) {
      if (xp >= (rank['minXP'] as int)) current = rank;
    }
    return current;
  }

  static Map<String, dynamic>? nextRankForXP(int xp) {
    for (int i = 0; i < ranks.length - 1; i++) {
      if (xp < (ranks[i + 1]['minXP'] as int)) return ranks[i + 1];
    }
    return null; // already at max rank
  }

  static double rankProgressPercent(int xp) {
    final current = rankForXP(xp);
    final next = nextRankForXP(xp);
    if (next == null) return 1.0;
    final currentMin = current['minXP'] as int;
    final nextMin = next['minXP'] as int;
    return (xp - currentMin) / (nextMin - currentMin);
  }

  // ── Fetch the user's current progress ─────────────────────
  static Future<Map<String, dynamic>> getProgress() async {
    final doc = _progressDoc;
    if (doc == null) return _defaultProgress();
    try {
      final snap = await doc.get();
      if (!snap.exists) return _defaultProgress();
      return snap.data() as Map<String, dynamic>;
    } catch (_) {
      return _defaultProgress();
    }
  }

  static Map<String, dynamic> _defaultProgress() => {
    'xp': 0,
    'rank': 'Bronze',
    'streak': 0,
    'longestStreak': 0,
    'lastActiveDate': '',
    'achievements': <Map<String, dynamic>>[],
    'examHistory': <Map<String, dynamic>>[],
    'xpHistory': <Map<String, dynamic>>[],
    'mockTestCount': 0,
    'jobsAppliedCount': 0,
    'chaptersReadCount': 0,
  };

  // ── Core XP award method ────────────────────────────────────
  // All XP awards go through this method, which also checks for
  // newly unlocked achievements and rank-ups automatically.
  static Future<ProgressUpdateResult> awardXP(String action, int amount) async {
    final doc = _progressDoc;
    if (doc == null) return ProgressUpdateResult.empty();

    try {
      final snap = await doc.get();
      Map<String, dynamic> data = snap.exists
          ? (snap.data() as Map<String, dynamic>)
          : _defaultProgress();

      final oldXP = (data['xp'] as num?)?.toInt() ?? 0;
      final newXP = oldXP + amount;
      final oldRank = data['rank'] as String? ?? 'Bronze';
      final newRankData = rankForXP(newXP);
      final newRank = newRankData['name'] as String;
      final didRankUp = newRank != oldRank;

      // Update counters based on action type
      if (action == 'mock_test_completed') {
        data['mockTestCount'] = ((data['mockTestCount'] as num?)?.toInt() ?? 0) + 1;
      } else if (action == 'job_applied') {
        data['jobsAppliedCount'] = ((data['jobsAppliedCount'] as num?)?.toInt() ?? 0) + 1;
      } else if (action == 'chapter_read') {
        data['chaptersReadCount'] = ((data['chaptersReadCount'] as num?)?.toInt() ?? 0) + 1;
      }

      // Add to XP history (keep last 50 entries)
      final xpHistory = List<Map<String, dynamic>>.from(
        (data['xpHistory'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? [],
      );
      xpHistory.insert(0, {
        'action': action,
        'xp': amount,
        'date': DateTime.now().toIso8601String(),
      });
      if (xpHistory.length > 50) xpHistory.removeLast();

      data['xp'] = newXP;
      data['rank'] = newRank;
      data['xpHistory'] = xpHistory;

      // Check for newly unlocked achievements
      final newlyUnlocked = await _checkAchievements(data);

      // Award XP for rank-up achievements
      int bonusXP = 0;
      if (didRankUp) {
        final rankAchievementId = _rankAchievementId(newRank);
        if (rankAchievementId != null &&
            !_hasAchievement(data, rankAchievementId) &&
            !newlyUnlocked.any((a) => a['id'] == rankAchievementId)) {
          final achDef = achievementDefs.firstWhere(
                (a) => a['id'] == rankAchievementId,
            orElse: () => {},
          );
          if (achDef.isNotEmpty) {
            newlyUnlocked.add({
              'id': rankAchievementId,
              'title': achDef['title'],
              'icon': achDef['icon'],
              'earnedAt': DateTime.now().toIso8601String(),
            });
            bonusXP += (achDef['xp'] as int? ?? 0);
          }
        }
      }

      // Add bonus XP for achievements
      if (bonusXP > 0) {
        data['xp'] = (data['xp'] as int) + bonusXP;
        data['rank'] = rankForXP(data['xp'] as int)['name'] as String;
      }

      // Merge newly unlocked achievements
      if (newlyUnlocked.isNotEmpty) {
        final achievements = List<Map<String, dynamic>>.from(
          (data['achievements'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? [],
        );
        achievements.addAll(newlyUnlocked);
        data['achievements'] = achievements;
      }

      await doc.set(data, SetOptions(merge: true));

      return ProgressUpdateResult(
        newXP: data['xp'] as int,
        newRank: data['rank'] as String,
        didRankUp: didRankUp,
        newlyUnlockedAchievements: newlyUnlocked,
        xpAwarded: amount + bonusXP,
      );
    } catch (e) {
      return ProgressUpdateResult.empty();
    }
  }

  // ── Streak management ───────────────────────────────────────
  static Future<ProgressUpdateResult> recordDailyOpen() async {
    final doc = _progressDoc;
    if (doc == null) return ProgressUpdateResult.empty();

    try {
      final snap = await doc.get();
      Map<String, dynamic> data = snap.exists
          ? (snap.data() as Map<String, dynamic>)
          : _defaultProgress();

      final today = _dateString(DateTime.now());
      final lastActive = data['lastActiveDate'] as String? ?? '';

      if (lastActive == today) {
        // Already opened today — no streak change, no XP
        return ProgressUpdateResult.empty();
      }

      final yesterday = _dateString(DateTime.now().subtract(const Duration(days: 1)));
      int streak = (data['streak'] as num?)?.toInt() ?? 0;
      int longestStreak = (data['longestStreak'] as num?)?.toInt() ?? 0;

      if (lastActive == yesterday) {
        // Streak continues
        streak += 1;
      } else {
        // Streak broken — reset to 1
        streak = 1;
      }

      longestStreak = streak > longestStreak ? streak : longestStreak;
      data['streak'] = streak;
      data['longestStreak'] = longestStreak;
      data['lastActiveDate'] = today;

      await doc.set(data, SetOptions(merge: true));

      // Award daily XP
      int totalXP = xpDailyOpen + xpStreakDaily;

      // Streak milestone bonuses
      final List<String> milestoneAchievements = [];
      if (streak == 7) milestoneAchievements.add('streak_7');
      if (streak == 30) milestoneAchievements.add('streak_30');

      final result = await awardXP('daily_open', totalXP);

      // Award streak milestones
      if (milestoneAchievements.isNotEmpty) {
        await awardXP('streak_milestone', xpStreakMilestone * milestoneAchievements.length);
      }

      return ProgressUpdateResult(
        newXP: result.newXP,
        newRank: result.newRank,
        didRankUp: result.didRankUp,
        newlyUnlockedAchievements: result.newlyUnlockedAchievements,
        xpAwarded: totalXP,
        newStreak: streak,
      );
    } catch (e) {
      return ProgressUpdateResult.empty();
    }
  }

  // ── Exam history ─────────────────────────────────────────────
  static Future<void> addExamHistory({
    required String examName,
    required String status, // 'applied' | 'appeared' | 'passed' | 'failed'
    required String source, // 'app' | 'manual'
  }) async {
    final doc = _progressDoc;
    if (doc == null) return;

    try {
      await doc.set({
        'examHistory': FieldValue.arrayUnion([{
          'examName': examName,
          'status': status,
          'date': DateTime.now().toIso8601String(),
          'source': source,
        }]),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // ── Achievement checking ────────────────────────────────────
  static Future<List<Map<String, dynamic>>> _checkAchievements(
      Map<String, dynamic> data,
      ) async {
    final List<Map<String, dynamic>> newlyUnlocked = [];
    final existingIds = (data['achievements'] as List?)
        ?.map((e) => (e as Map)['id'] as String)
        .toSet() ?? <String>{};

    void checkAndUnlock(String id) {
      if (existingIds.contains(id)) return;
      final def = achievementDefs.firstWhere(
            (a) => a['id'] == id,
        orElse: () => {},
      );
      if (def.isEmpty) return;
      newlyUnlocked.add({
        'id': id,
        'title': def['title'],
        'icon': def['icon'],
        'earnedAt': DateTime.now().toIso8601String(),
      });
      existingIds.add(id);
    }

    // first_open is awarded on first data creation — always check
    checkAndUnlock('first_open');

    final mockCount = (data['mockTestCount'] as num?)?.toInt() ?? 0;
    if (mockCount >= 1) checkAndUnlock('first_mock');
    if (mockCount >= 5) checkAndUnlock('mock_5');

    final jobCount = (data['jobsAppliedCount'] as num?)?.toInt() ?? 0;
    if (jobCount >= 1) checkAndUnlock('first_apply');
    if (jobCount >= 10) checkAndUnlock('jobs_10');

    final chapterCount = (data['chaptersReadCount'] as num?)?.toInt() ?? 0;
    if (chapterCount >= 10) checkAndUnlock('chapters_10');

    return newlyUnlocked;
  }

  static bool _hasAchievement(Map<String, dynamic> data, String id) {
    return (data['achievements'] as List?)
        ?.any((a) => (a as Map)['id'] == id) ?? false;
  }

  static String? _rankAchievementId(String rankName) {
    switch (rankName) {
      case 'Silver':   return 'rank_up_silver';
      case 'Gold':     return 'rank_up_gold';
      case 'Platinum': return 'rank_up_platinum';
      default: return null;
    }
  }

  static String _dateString(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

/// Returned by XP-awarding methods so the UI knows what
/// happened and can show the right feedback (rank-up animation,
/// achievement toast, XP popup, etc.)
class ProgressUpdateResult {
  final int newXP;
  final String newRank;
  final bool didRankUp;
  final List<Map<String, dynamic>> newlyUnlockedAchievements;
  final int xpAwarded;
  final int? newStreak;

  ProgressUpdateResult({
    required this.newXP,
    required this.newRank,
    required this.didRankUp,
    required this.newlyUnlockedAchievements,
    required this.xpAwarded,
    this.newStreak,
  });

  factory ProgressUpdateResult.empty() => ProgressUpdateResult(
    newXP: 0, newRank: '', didRankUp: false,
    newlyUnlockedAchievements: [], xpAwarded: 0,
  );

  bool get hasUpdate => xpAwarded > 0 || didRankUp || newlyUnlockedAchievements.isNotEmpty;
}