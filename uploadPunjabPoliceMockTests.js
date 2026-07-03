// uploadPunjabPoliceMockTests.js
// Uploads Mock Tests 2, 3, 4 for Punjab Police to Firestore
//
// Run from C:\examtrack:
//   node uploadPunjabPoliceMockTests.js
//
// Firestore structure:
//   mockTests/{examId}/tests/{testId}          — test summary
//   mockTests/{examId}/tests/{testId}/questions — subcollection

const admin = require('firebase-admin');
const path  = require('path');
const fs    = require('fs');

const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const data = JSON.parse(
  fs.readFileSync(path.join(__dirname, 'punjab_police_mock_tests.json'), 'utf8')
);

const mockTests = data.mockTests;
const EXAM_ID   = 'Punjab Police';

async function upload() {
  console.log(`\nUploading ${mockTests.length} mock tests for ${EXAM_ID}...\n`);

  for (const test of mockTests) {
    const testId    = test.id;
    const questions = test.questions;

    // Summary doc (no questions field — stored in subcollection)
    const summary = {
      id:             testId,
      examId:         test.examId,
      title:          test.title,
      description:    test.description,
      duration:       test.duration,
      totalQuestions: test.totalQuestions,
      totalMarks:     test.totalMarks,
      difficulty:     test.difficulty,
      year:           test.year,
      isTimed:        test.isTimed,
      isUntimed:      test.isUntimed,
      updatedAt:      admin.firestore.FieldValue.serverTimestamp(),
    };

    const testRef = db
      .collection('mockTests')
      .doc(EXAM_ID)
      .collection('tests')
      .doc(testId);

    await testRef.set(summary);
    console.log(`✅ Summary saved: ${testId}`);

    // Upload questions as subcollection
    const batch = db.batch();
    for (const q of questions) {
      const qRef = testRef.collection('questions').doc(q.id);
      batch.set(qRef, q);
    }
    await batch.commit();
    console.log(`   └─ ${questions.length} questions uploaded`);
  }

  console.log('\n─────────────────────────────────────────');
  console.log(`✅ Done! ${mockTests.length} mock tests uploaded.`);
  console.log('─────────────────────────────────────────\n');
  process.exit(0);
}

upload().catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});
