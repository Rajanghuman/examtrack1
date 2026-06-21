import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MemoryBoxService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>>? get _collection {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('memoryBox');
  }

  /// Call this whenever a user answers a question WRONG in any quiz,
  /// PYQ practice, or mock test. Safe to call even if not logged in
  /// (it will just silently skip).
  ///
  /// [questionId] should be a stable, unique id for the question —
  /// e.g. '${exam}_${subject}_${q['id']}' — so the same wrong question
  /// from different sessions merges into one Memory Box entry.
  static Future<void> saveWrongAnswer({
    required String questionId,
    required String question,
    required List<String> options,
    required int correctIndex,
    required String explanation,
    required String topic,
    required String exam,
  }) async {
    final col = _collection;
    if (col == null) return;

    try {
      final docRef = col.doc(questionId);
      final existing = await docRef.get();

      if (existing.exists) {
        final data = existing.data()!;
        final wrongCount = (data['wrongCount'] as int? ?? 0) + 1;
        await docRef.update({
          'wrongCount': wrongCount,
          'lastAttempted': FieldValue.serverTimestamp(),
          'nextReviewDate': _nextReviewDate(wrongCount),
          'mastered': false,
        });
      } else {
        await docRef.set({
          'question': question,
          'options': options,
          'correctIndex': correctIndex,
          'explanation': explanation,
          'topic': topic,
          'exam': exam,
          'wrongCount': 1,
          'lastAttempted': FieldValue.serverTimestamp(),
          'nextReviewDate': _nextReviewDate(1),
          'mastered': false,
          'addedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      // Fail silently — Memory Box saving should never block the quiz flow
    }
  }

  /// Call this when a user gets a Memory Box question RIGHT during a
  /// revision quiz. After 2 consecutive correct answers, it's removed
  /// (marked mastered) from the box.
  static Future<void> markCorrectInRevision(String questionId) async {
    final col = _collection;
    if (col == null) return;

    try {
      final docRef = col.doc(questionId);
      final existing = await docRef.get();
      if (!existing.exists) return;

      final data = existing.data()!;
      final correctStreak = (data['correctStreak'] as int? ?? 0) + 1;

      if (correctStreak >= 2) {
        // Mastered — remove from active box
        await docRef.delete();
      } else {
        await docRef.update({
          'correctStreak': correctStreak,
          'lastAttempted': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      // Fail silently
    }
  }

  /// Call this when a user gets a Memory Box question WRONG again
  /// during a revision quiz — resets streak and pushes next review out.
  static Future<void> markWrongInRevision(String questionId) async {
    final col = _collection;
    if (col == null) return;

    try {
      final docRef = col.doc(questionId);
      final existing = await docRef.get();
      if (!existing.exists) return;

      final data = existing.data()!;
      final wrongCount = (data['wrongCount'] as int? ?? 0) + 1;

      await docRef.update({
        'wrongCount': wrongCount,
        'correctStreak': 0,
        'lastAttempted': FieldValue.serverTimestamp(),
        'nextReviewDate': _nextReviewDate(wrongCount),
      });
    } catch (e) {
      // Fail silently
    }
  }

  /// Returns ALL Memory Box questions for the current user, optionally
  /// filtered by exam. Used for the topic breakdown screen.
  static Future<List<Map<String, dynamic>>> getAllQuestions({String? exam}) async {
    final col = _collection;
    if (col == null) return [];

    try {
      Query<Map<String, dynamic>> query = col;
      if (exam != null) {
        query = query.where('exam', isEqualTo: exam);
      }
      final snapshot = await query.get();
      return snapshot.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Returns only questions that are DUE for review today (nextReviewDate
  /// <= now). This powers the "8 questions due today" home screen alert
  /// and the actual Revision Quiz question set.
  static Future<List<Map<String, dynamic>>> getDueQuestions({String? exam}) async {
    final col = _collection;
    if (col == null) return [];

    try {
      Query<Map<String, dynamic>> query = col.where(
        'nextReviewDate',
        isLessThanOrEqualTo: Timestamp.now(),
      );
      if (exam != null) {
        query = query.where('exam', isEqualTo: exam);
      }
      final snapshot = await query.get();
      return snapshot.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Quick count for the home screen alert card — how many questions
  /// are due for revision right now.
  static Future<int> getDueCount() async {
    final due = await getDueQuestions();
    return due.length;
  }

  /// Topic-wise breakdown — e.g. {'Analogies': 8, 'Percentage': 6, ...}
  /// sorted by count descending. Used for the weak-area chart.
  static Future<List<MapEntry<String, int>>> getTopicBreakdown({String? exam}) async {
    final all = await getAllQuestions(exam: exam);
    final Map<String, int> counts = {};
    for (final q in all) {
      final topic = q['topic'] as String? ?? 'General';
      counts[topic] = (counts[topic] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted;
  }

  /// Spaced repetition schedule:
  /// 1st wrong  -> review again in 3 days
  /// 2nd wrong  -> review again in 1 day
  /// 3rd+ wrong -> review again today/tomorrow (aggressive)
  static Timestamp _nextReviewDate(int wrongCount) {
    final now = DateTime.now();
    DateTime next;
    if (wrongCount <= 1) {
      next = now.add(const Duration(days: 3));
    } else if (wrongCount == 2) {
      next = now.add(const Duration(days: 1));
    } else {
      next = now.add(const Duration(hours: 12));
    }
    return Timestamp.fromDate(next);
  }
}
