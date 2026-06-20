import 'package:cloud_firestore/cloud_firestore.dart';

class JobService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Get all jobs ───────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAllJobs() async {
    try {
      QuerySnapshot snapshot = await _db
          .collection('jobs')
          .get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // ── Get jobs by category ───────────────────────────────
  Future<List<Map<String, dynamic>>> getJobsByCategory(
      String category) async {
    try {
      QuerySnapshot snapshot = await _db
          .collection('jobs')
          .where('category', isEqualTo: category)
          .get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // ── Get new jobs ───────────────────────────────────────
  Future<List<Map<String, dynamic>>> getNewJobs() async {
    try {
      // First try to get isNew jobs
      QuerySnapshot snapshot = await _db
          .collection('jobs')
          .where('isNew', isEqualTo: true)
          .limit(4)
          .get();

      if (snapshot.docs.isEmpty) {
        // If no new jobs get any 4 jobs
        QuerySnapshot allSnapshot = await _db
            .collection('jobs')
            .limit(4)
            .get();
        return allSnapshot.docs.map((doc) {
          Map<String, dynamic> data =
          doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();
      }

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data =
        doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      // Fallback — get any jobs
      try {
        QuerySnapshot allSnapshot = await _db
            .collection('jobs')
            .limit(4)
            .get();
        return allSnapshot.docs.map((doc) {
          Map<String, dynamic> data =
          doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();
      } catch (e2) {
        return [];
      }
    }
  }

  // ── Search jobs ────────────────────────────────────────
  Future<List<Map<String, dynamic>>> searchJobs(String query) async {
    try {
      QuerySnapshot snapshot = await _db
          .collection('jobs')
          .get();

      List<Map<String, dynamic>> allJobs =
      snapshot.docs.map((doc) {
        Map<String, dynamic> data =
        doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      return allJobs.where((job) {
        String title =
        (job['title'] ?? '').toString().toLowerCase();
        String org =
        (job['organization'] ?? '').toString().toLowerCase();
        String searchLower = query.toLowerCase();
        return title.contains(searchLower) ||
            org.contains(searchLower);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // ── Add job (for admin) ────────────────────────────────
  Future<bool> addJob(Map<String, dynamic> jobData) async {
    try {
      await _db.collection('jobs').add(jobData);
      return true;
    } catch (e) {
      return false;
    }
  }
}
