import 'package:cloud_firestore/cloud_firestore.dart';

class StudyMaterialService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // In-memory cache: examId -> flat list of chapter documents.
  // Cleared only when the app restarts (per the earlier decision to
  // keep this simple — no local disk persistence for now).
  static final Map<String, List<Map<String, dynamic>>> _cache = {};

  // Maps the app's display exam names (used in _selectedExam) to the
  // clean examId slugs used as Firestore document keys.
  static const Map<String, String> _examIdMap = {
    'SSC CGL': 'ssc-cgl',
    'SSC CHSL': 'ssc-chsl',
    'Punjab Police': 'punjab-police-constable',
    // Add more mappings here as more exams are migrated to Firestore.
    // Any exam NOT listed here falls back to local StudyData (see
    // study_material_screen.dart's _sections getter).
  };

  /// Returns true if this exam's study material has been migrated to
  /// Firestore. Used by the screen to decide whether to call this
  /// service or fall back to the local StudyData class.
  static bool isFirestoreBacked(String exam) => _examIdMap.containsKey(exam);

  /// Fetches all chapters for a given exam (by its display name, e.g.
  /// 'SSC CGL'), groups them into the Subject -> Part -> Chapter tree
  /// shape the UI expects, and returns it as a List<Map> matching
  /// exactly what StudyData.getSections() used to return locally.
  ///
  /// Results are cached in memory per exam for the app session, so
  /// repeated calls (e.g. switching back to an already-loaded exam)
  /// don't re-fetch from Firestore.
  static Future<List<Map<String, dynamic>>> getSections(
    String exam, {
    bool forceRefresh = false,
  }) async {
    final examId = _examIdMap[exam];
    if (examId == null) return [];

    if (!forceRefresh && _cache.containsKey(examId)) {
      return _cache[examId]!;
    }

    try {
      final snapshot = await _db
          .collection('studyMaterialChapters')
          .where('examId', isEqualTo: examId)
          .get();

      if (snapshot.docs.isEmpty) {
        _cache[examId] = [];
        return [];
      }

      final flatChapters = snapshot.docs.map((doc) => doc.data()).toList();
      final grouped = _groupIntoSections(flatChapters);

      _cache[examId] = grouped;
      return grouped;
    } catch (e) {
      // On error, return cached data if we have any (stale but usable),
      // otherwise an empty list — the screen's existing loading/error
      // pattern (mirroring _mockLoadError) handles showing a retry UI.
      return _cache[examId] ?? [];
    }
  }

  /// Clears the cache for one exam (or all exams if none specified).
  /// Call this on manual pull-to-refresh if/when that's added.
  static void clearCache([String? exam]) {
    if (exam == null) {
      _cache.clear();
      return;
    }
    final examId = _examIdMap[exam];
    if (examId != null) _cache.remove(examId);
  }

  // ── Grouping logic ──────────────────────────────────────────────
  // Converts the flat Firestore chapter list into the nested
  // Subject -> Part -> Chapter structure the UI already expects
  // (same shape as the old StudyData.getSections() return value).
  static List<Map<String, dynamic>> _groupIntoSections(
    List<Map<String, dynamic>> flatChapters,
  ) {
    // Group by subjectId first, preserving subject order.
    final Map<String, Map<String, dynamic>> subjectsById = {};

    for (final ch in flatChapters) {
      final subjectId = ch['subjectId'] as String? ?? 'unknown';

      subjectsById.putIfAbsent(subjectId, () => {
            'id': subjectId,
            'title': ch['subjectTitle'] ?? '',
            'colorHex': ch['subjectColorHex'] ?? 0xFF1565C0,
            '_order': ch['subjectOrder'] ?? 0,
            '_partsById': <String, Map<String, dynamic>>{},
          });

      final subject = subjectsById[subjectId]!;
      final partsById =
          subject['_partsById'] as Map<String, Map<String, dynamic>>;
      final partId = ch['partId'] as String? ?? 'unknown';

      partsById.putIfAbsent(partId, () => {
            'id': partId,
            'title': ch['partTitle'] ?? '',
            '_order': ch['partOrder'] ?? 0,
            '_chapters': <Map<String, dynamic>>[],
          });

      final part = partsById[partId]!;
      final chaptersList = part['_chapters'] as List<Map<String, dynamic>>;

      chaptersList.add({
        'id': ch['chapterId'] ?? '',
        'title': ch['chapterTitle'] ?? '',
        'weightage': ch['weightage'] ?? '',
        'difficulty': ch['difficulty'] ?? '',
        'readTime': ch['readTime'] ?? '',
        'content': ch['content'] ?? '',
        '_order': ch['chapterOrder'] ?? 0,
      });
    }

    // Sort subjects by order, then sort parts within each subject,
    // then sort chapters within each part — and strip the internal
    // '_order'/'_partsById' helper keys before returning, since the
    // UI doesn't expect those.
    final sortedSubjects = subjectsById.values.toList()
      ..sort((a, b) => (a['_order'] as int).compareTo(b['_order'] as int));

    return sortedSubjects.map((subject) {
      final partsById =
          subject['_partsById'] as Map<String, Map<String, dynamic>>;
      final sortedParts = partsById.values.toList()
        ..sort((a, b) => (a['_order'] as int).compareTo(b['_order'] as int));

      final cleanParts = sortedParts.map((part) {
        final chapters = part['_chapters'] as List<Map<String, dynamic>>
          ..sort((a, b) => (a['_order'] as int).compareTo(b['_order'] as int));

        final cleanChapters = chapters.map((ch) {
          final copy = Map<String, dynamic>.from(ch);
          copy.remove('_order');
          return copy;
        }).toList();

        return {
          'id': part['id'],
          'title': part['title'],
          'chapters': cleanChapters,
        };
      }).toList();

      return {
        'id': subject['id'],
        'title': subject['title'],
        'colorHex': subject['colorHex'],
        'parts': cleanParts,
      };
    }).toList();
  }
}
