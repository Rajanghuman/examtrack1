import 'package:cloud_firestore/cloud_firestore.dart';

class MockTestService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<List<Map<String, dynamic>>> getMockTests(String exam) async {
    try {
      final examKey = _examKey(exam);

      // Try primary key first (space-based: "Punjab Police")
      // then fall back to underscore key ("Punjab_Police")
      // This handles both old and new upload conventions.
      QuerySnapshot snapshot = await _db
          .collection('mockTests')
          .doc(exam) // try exact exam name first e.g. "Punjab Police"
          .collection('tests')
          .get();

      // If empty, try the underscore-normalized key
      if (snapshot.docs.isEmpty) {
        snapshot = await _db
            .collection('mockTests')
            .doc(examKey) // e.g. "Punjab_Police"
            .collection('tests')
            .get();
      }

      if (snapshot.docs.isEmpty) return [];

      final results = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['firestoreId'] = doc.id;
        return data;
      }).toList();

      // Sort client-side by 'order' if present, otherwise by 'id'
      results.sort((a, b) {
        final aOrder = a['order'] as int? ?? 999;
        final bOrder = b['order'] as int? ?? 999;
        if (aOrder != bOrder) return aOrder.compareTo(bOrder);
        // fallback: sort by id string
        return (a['id'] as String? ?? '').compareTo(b['id'] as String? ?? '');
      });

      return results;
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getMockTestWithQuestions(
      String exam, String testId) async {
    try {
      // Try both key formats
      final keys = [exam, _examKey(exam)];

      for (final key in keys) {
        final testDoc = await _db
            .collection('mockTests')
            .doc(key)
            .collection('tests')
            .doc(testId)
            .get();

        if (!testDoc.exists) continue;

        final data = testDoc.data()!;

        // Fetch questions — try orderBy('order'), fall back to no ordering
        QuerySnapshot questionsSnap;
        try {
          questionsSnap = await _db
              .collection('mockTests')
              .doc(key)
              .collection('tests')
              .doc(testId)
              .collection('questions')
              .orderBy('order')
              .get();
        } catch (_) {
          // No 'order' field — just fetch without ordering
          questionsSnap = await _db
              .collection('mockTests')
              .doc(key)
              .collection('tests')
              .doc(testId)
              .collection('questions')
              .get();
        }

        data['questions'] = questionsSnap.docs
            .map((q) => q.data() as Map<String, dynamic>)
            .toList();

        return data;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  static String _examKey(String exam) {
    return exam
        .replaceAll(' ', '_')
        .replaceAll('/', '_')
        .replaceAll('&', 'and');
  }
}