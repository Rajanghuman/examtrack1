import 'package:cloud_firestore/cloud_firestore.dart';

class MockTestService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Fetch all mock tests for a given exam from Firestore
  static Future<List<Map<String, dynamic>>> getMockTests(String exam) async {
    try {
      // Normalize exam name to use as Firestore document key
      final examKey = _examKey(exam);

      final snapshot = await _db
          .collection('mockTests')
          .doc(examKey)
          .collection('tests')
          .orderBy('order')
          .get();

      if (snapshot.docs.isEmpty) return [];

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['firestoreId'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Fetch a single mock test with all its questions
  static Future<Map<String, dynamic>?> getMockTestWithQuestions(
      String exam, String testId) async {
    try {
      final examKey = _examKey(exam);

      final testDoc = await _db
          .collection('mockTests')
          .doc(examKey)
          .collection('tests')
          .doc(testId)
          .get();

      if (!testDoc.exists) return null;

      final data = testDoc.data()!;

      // Fetch questions subcollection
      final questionsSnap = await _db
          .collection('mockTests')
          .doc(examKey)
          .collection('tests')
          .doc(testId)
          .collection('questions')
          .orderBy('order')
          .get();

      data['questions'] = questionsSnap.docs
          .map((q) => q.data())
          .toList();

      return data;
    } catch (e) {
      return null;
    }
  }

  // Convert exam name to Firestore-safe key
  static String _examKey(String exam) {
    return exam
        .replaceAll(' ', '_')
        .replaceAll('/', '_')
        .replaceAll('&', 'and');
  }
}
