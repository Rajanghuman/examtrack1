// uploadMockTests.js
// Uploads all mock test batch JSON files into Firestore under:
//   mockTests/{examKey}/tests/{testId}            <- test metadata
//   mockTests/{examKey}/tests/{testId}/questions/{n} <- individual questions
//
// Usage:
//   node uploadMockTests.js
//
// Requires: serviceAccountKey.json in the same directory (same one
// used by uploadJobs.js / uploadQuiz.js)

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// All 7 batch files from this session
const files = [
  'mocktests_batch1/ssc_chsl.json',
  'mocktests_batch1/upsc_cse.json',
  'mocktests_batch1/delhi_police.json',
  'mocktests_batch1/haryana_police.json',
  'mocktests_batch1/nda.json',
  'mocktests_batch1/army_agniveer.json',
  'mocktests_batch1/punjab_police.json',
];

async function uploadFile(filePath) {
  const fullPath = path.join(__dirname, filePath);
  const raw = fs.readFileSync(fullPath, 'utf-8');
  const data = JSON.parse(raw);

  const examKey = data.examKey;
  console.log(`\n📘 ${examKey} — ${data.tests.length} tests`);

  for (const test of data.tests) {
    const { questions, ...testMeta } = test;

    // 1. Write the test metadata document
    const testRef = db
      .collection('mockTests')
      .doc(examKey)
      .collection('tests')
      .doc(test.id);

    await testRef.set({
      ...testMeta,
      totalQ: questions.length,
    });

    // 2. Write each question as its own document in the subcollection
    const batch = db.batch();
    questions.forEach((q) => {
      const qRef = testRef.collection('questions').doc(`q${q.order}`);
      batch.set(qRef, q);
    });
    await batch.commit();

    console.log(`   ✅ ${test.id} — ${questions.length} questions uploaded`);
  }
}

async function main() {
  console.log('🚀 Starting mock test upload to Firestore...');
  let totalTests = 0;
  let totalQuestions = 0;

  for (const file of files) {
    const raw = JSON.parse(fs.readFileSync(path.join(__dirname, file), 'utf-8'));
    totalTests += raw.tests.length;
    totalQuestions += raw.tests.reduce((sum, t) => sum + t.questions.length, 0);
    await uploadFile(file);
  }

  console.log(`\n🎉 DONE! Uploaded ${totalTests} tests, ${totalQuestions} questions across 7 exams.`);
  process.exit(0);
}

main().catch((err) => {
  console.error('❌ Upload failed:', err);
  process.exit(1);
});
