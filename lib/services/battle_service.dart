import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:examtrack/services/progress_service.dart';

// ============================================================
// BattleService — handles all 1v1 quiz battle logic.
//
// Firestore structure:
//   battleRooms/{roomCode}
//     - mode: 'live' | 'challenge'
//     - status: 'waiting'|'countdown'|'active'|'p1_done'|'completed'
//     - createdBy: userId
//     - topic: string
//     - questionCount: int
//     - timerSeconds: int
//     - questions: List<Map> (AI generated)
//     - players: {
//         p1: {uid, name, score, answers: [], completedAt}
//         p2: {uid, name, score, answers: [], completedAt}
//       }
//     - winnerId: null | userId | 'draw'
//     - createdAt: timestamp
//     - expiresAt: timestamp (challenge mode: 24hr expiry)
// ============================================================

class BattleService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static final _functions = FirebaseFunctions.instance;

  // XP rewards
  static const int xpWin = 100;
  static const int xpDraw = 30;
  static const int xpLose = 20;

  static String? get _uid => _auth.currentUser?.uid;
  static String get _displayName =>
      _auth.currentUser?.displayName ?? 'Player';

  // ── Generate a unique 6-digit room code ──────────────────────
  static Future<String> _generateRoomCode() async {
    final random = Random();
    while (true) {
      final code = (100000 + random.nextInt(900000)).toString();
      final existing = await _db.collection('battleRooms').doc(code).get();
      if (!existing.exists) return code;
    }
  }

  // ── Create a new battle room ─────────────────────────────────
  // Calls the Cloud Function to generate questions, then creates
  // the Firestore room document.
  static Future<BattleRoom> createRoom({
    required String mode, // 'live' | 'challenge'
    required String topic,
    required int questionCount,
    required int timerSeconds,
    String difficulty = 'medium', // 'easy' | 'medium' | 'hard'
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not signed in');

    // Call Cloud Function to generate questions
    final questions = await _generateQuestions(topic, questionCount, difficulty);

    // Generate room code
    final roomCode = await _generateRoomCode();

    final now = DateTime.now();
    final roomData = {
      'mode': mode,
      'status': 'waiting',
      'createdBy': uid,
      'topic': topic,
      'questionCount': questionCount,
      'timerSeconds': timerSeconds,
      'questions': questions,
      'players': {
        'p1': {
          'uid': uid,
          'name': _displayName,
          'score': 0,
          'answers': <int>[],
          'completedAt': null,
        },
        'p2': null,
      },
      'winnerId': null,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        now.add(const Duration(hours: 24)),
      ),
    };

    await _db.collection('battleRooms').doc(roomCode).set(roomData);

    return BattleRoom(
      roomCode: roomCode,
      mode: mode,
      topic: topic,
      questionCount: questionCount,
      timerSeconds: timerSeconds,
      questions: questions,
      status: 'waiting',
      createdBy: uid,
      players: {'p1': roomData['players'] as Map},
    );
  }

  // ── Join an existing room by code ────────────────────────────
  static Future<BattleRoom> joinRoom(String roomCode) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not signed in');

    final code = roomCode.trim().toUpperCase();
    final docRef = _db.collection('battleRooms').doc(code);
    final snap = await docRef.get();

    if (!snap.exists) {
      throw Exception('Room not found. Check the code and try again.');
    }

    final data = snap.data()!;

    // Validate room state
    if (data['status'] != 'waiting') {
      throw Exception('This battle has already started or ended.');
    }
    if (data['createdBy'] == uid) {
      throw Exception('You cannot join your own room from this screen.');
    }
    final players = data['players'] as Map;
    if (players['p2'] != null) {
      throw Exception('This room is already full.');
    }

    // Check expiry
    final expiresAt = (data['expiresAt'] as Timestamp).toDate();
    if (DateTime.now().isAfter(expiresAt)) {
      throw Exception('This challenge has expired.');
    }

    // Add player 2
    await docRef.update({
      'players.p2': {
        'uid': uid,
        'name': _displayName,
        'score': 0,
        'answers': <int>[],
        'completedAt': null,
      },
      'status': data['mode'] == 'live' ? 'countdown' : 'active',
    });

    final questions = (data['questions'] as List)
        .map((q) => Map<String, dynamic>.from(q as Map))
        .toList();

    return BattleRoom(
      roomCode: code,
      mode: data['mode'] as String,
      topic: data['topic'] as String,
      questionCount: data['questionCount'] as int,
      timerSeconds: data['timerSeconds'] as int,
      questions: questions,
      status: data['mode'] == 'live' ? 'countdown' : 'active',
      createdBy: data['createdBy'] as String,
      players: Map<String, dynamic>.from(players),
    );
  }

  // ── Listen to room updates in real-time ──────────────────────
  static Stream<BattleRoom> watchRoom(String roomCode) {
    return _db
        .collection('battleRooms')
        .doc(roomCode)
        .snapshots()
        .map((snap) {
      if (!snap.exists) throw Exception('Room no longer exists.');
      final data = snap.data()!;
      final questions = (data['questions'] as List)
          .map((q) => Map<String, dynamic>.from(q as Map))
          .toList();
      return BattleRoom(
        roomCode: roomCode,
        mode: data['mode'] as String,
        topic: data['topic'] as String,
        questionCount: data['questionCount'] as int,
        timerSeconds: data['timerSeconds'] as int? ?? 15,
        questions: questions,
        status: data['status'] as String,
        createdBy: data['createdBy'] as String,
        players: Map<String, dynamic>.from(data['players'] as Map),
        winnerId: data['winnerId'] as String?,
      );
    });
  }

  // ── Submit an answer ─────────────────────────────────────────
  static Future<void> submitAnswer({
    required String roomCode,
    required String playerKey, // 'p1' or 'p2'
    required int questionIndex,
    required int answerIndex, // -1 = timed out
    required bool isCorrect,
  }) async {
    final docRef = _db.collection('battleRooms').doc(roomCode);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final data = snap.data()!;
      final players = Map<String, dynamic>.from(data['players'] as Map);
      final player =
      Map<String, dynamic>.from(players[playerKey] as Map);

      final answers = List<int>.from(player['answers'] as List? ?? []);
      answers.add(answerIndex);

      int score = (player['score'] as int? ?? 0);
      if (isCorrect) score++;

      tx.update(docRef, {
        'players.$playerKey.answers': answers,
        'players.$playerKey.score': score,
      });
    });
  }

  // ── Mark a player as done ────────────────────────────────────
  static Future<void> markPlayerDone({
    required String roomCode,
    required String playerKey,
    required int finalScore,
  }) async {
    final docRef = _db.collection('battleRooms').doc(roomCode);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final data = snap.data()!;
      final players = Map<String, dynamic>.from(data['players'] as Map);

      // Mark this player done
      tx.update(docRef, {
        'players.$playerKey.completedAt': FieldValue.serverTimestamp(),
        'players.$playerKey.score': finalScore,
        'status': _getOtherPlayerKey(playerKey) == 'p1'
            ? (players['p1'] != null &&
            (players['p1'] as Map)['completedAt'] != null
            ? 'completed'
            : '${playerKey}_done')
            : (players['p2'] != null &&
            (players['p2'] as Map)['completedAt'] != null
            ? 'completed'
            : '${playerKey}_done'),
      });

      // Check if both players are done
      final otherKey = _getOtherPlayerKey(playerKey);
      final otherPlayer = players[otherKey] as Map?;
      if (otherPlayer != null && otherPlayer['completedAt'] != null) {
        // Both done — determine winner
        final myScore = finalScore;
        final otherScore = (otherPlayer['score'] as int? ?? 0);
        final myUid = (players[playerKey] as Map)['uid'] as String;
        final otherUid = otherPlayer['uid'] as String;

        String winnerId;
        if (myScore > otherScore) {
          winnerId = myUid;
        } else if (otherScore > myScore) {
          winnerId = otherUid;
        } else {
          winnerId = 'draw';
        }

        tx.update(docRef, {
          'status': 'completed',
          'winnerId': winnerId,
        });

        // Award XP
        await _awardBattleXP(winnerId, myUid, otherUid);
      }
    });
  }

  // ── Start live battle (countdown → active) ───────────────────
  static Future<void> startBattle(String roomCode) async {
    await _db.collection('battleRooms').doc(roomCode).update({
      'status': 'active',
    });
  }

  // ── Award XP after battle completes ─────────────────────────
  static Future<void> _awardBattleXP(
      String winnerId,
      String p1Uid,
      String p2Uid,
      ) async {
    // Award XP to the current user based on outcome
    final uid = _uid;
    if (uid == null) return;

    int xp;
    String action;
    if (winnerId == 'draw') {
      xp = xpDraw;
      action = 'battle_draw';
    } else if (winnerId == uid) {
      xp = xpWin;
      action = 'battle_win';
    } else {
      xp = xpLose;
      action = 'battle_lose';
    }

    await ProgressService.awardXP(action, xp);
  }

  // ── Call Cloud Function to generate questions ────────────────
  static Future<List<Map<String, dynamic>>> _generateQuestions(
      String topic,
      int questionCount,
      String difficulty,
      ) async {
    try {
      final callable =
      _functions.httpsCallable('generateBattleQuestions');
      final result = await callable.call({
        'topic': topic,
        'questionCount': questionCount,
        'difficulty': difficulty,
      });

      final data = result.data as Map;
      final questions = (data['questions'] as List)
          .map((q) => Map<String, dynamic>.from(q as Map))
          .toList();

      return questions;
    } catch (e) {
      throw Exception(
        'Could not generate questions. Please check your connection and try again.',
      );
    }
  }

  // ── Helper: get the other player key ─────────────────────────
  static String _getOtherPlayerKey(String playerKey) {
    return playerKey == 'p1' ? 'p2' : 'p1';
  }

  // ── Get player key for current user ─────────────────────────
  static String getMyPlayerKey(BattleRoom room) {
    final uid = _uid;
    final players = room.players;
    if (players['p1'] != null &&
        (players['p1'] as Map)['uid'] == uid) return 'p1';
    return 'p2';
  }

  // ── Delete expired rooms (cleanup) ───────────────────────────
  static Future<void> cleanupExpiredRooms() async {
    final snap = await _db
        .collection('battleRooms')
        .where('expiresAt', isLessThan: Timestamp.now())
        .where('status', whereIn: ['waiting', 'p1_done'])
        .limit(20)
        .get();

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}

// ── BattleRoom data model ────────────────────────────────────
class BattleRoom {
  final String roomCode;
  final String mode;
  final String topic;
  final int questionCount;
  final int timerSeconds;
  final List<Map<String, dynamic>> questions;
  final String status;
  final String createdBy;
  final Map<String, dynamic> players;
  final String? winnerId;

  BattleRoom({
    required this.roomCode,
    required this.mode,
    required this.topic,
    required this.questionCount,
    required this.timerSeconds,
    required this.questions,
    required this.status,
    required this.createdBy,
    required this.players,
    this.winnerId,
  });

  bool get isCompleted => status == 'completed';
  bool get isActive => status == 'active';
  bool get isWaiting => status == 'waiting';
  bool get isCountdown => status == 'countdown';

  Map<String, dynamic>? get p1 =>
      players['p1'] != null
          ? Map<String, dynamic>.from(players['p1'] as Map)
          : null;

  Map<String, dynamic>? get p2 =>
      players['p2'] != null
          ? Map<String, dynamic>.from(players['p2'] as Map)
          : null;
}

// ── Available topics for battle ──────────────────────────────
class BattleTopics {
  static const List<String> exams = [
    'SSC CGL',
    'SSC CHSL',
    'SSC GD',
    'IBPS PO',
    'IBPS Clerk',
    'SBI PO',
    'RRB NTPC',
    'Punjab Police',
    'UP Police',
    'UPSC Prelims',
  ];

  static const List<String> subjects = [
    'General Knowledge',
    'Current Affairs',
    'Mathematics',
    'Reasoning',
    'English',
    'History',
    'Geography',
    'Science',
    'Indian Polity',
    'Economics',
    'Punjab GK',
  ];
}