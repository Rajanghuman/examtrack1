// uploadMockTestsBatch2.js
// Uploads SSC CGL, RRB NTPC, IBPS PO mock tests (batch 2) into Firestore.
// Same structure as uploadMockTests.js — safe to run independently,
// will NOT affect the 7 exams uploaded in batch 1.
//
// Usage:
//   node uploadMockTestsBatch2.js
//
// Requires: serviceAccountKey.json in the same directory

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const serviceAccount = require('./serviceAccountKey.json');

// Reuse existing app if already initialized (in case run alongside other scripts)
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const db = admin.firestore();

const files = [
  'mocktests_batch2/ssc_cgl.json',
  'mocktests_batch2/rrb_ntpc.json',
  'mocktests_batch2/ibps_po.json',
];

async function uploadFile(filePath) {
  const fullPath = path.join(__dirname, filePath);
  const raw = fs.readFileSync(fullPath, 'utf-8');
  const data = JSON.parse(raw);

  const examKey = data.examKey;
  console.log(`\n📘 ${examKey} — ${data.tests.length} tests`);

  for (const test of data.tests) {
    const { questions, ...testMeta } = test;

    const testRef = db
      .collection('mockTests')
      .doc(examKey)
      .collection('tests')
      .doc(test.id);

    await testRef.set({
      ...testMeta,
      totalQ: questions.length,
    });

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
  console.log('🚀 Starting mock test upload (Batch 2) to Firestore...');
  let totalTests = 0;
  let totalQuestions = 0;

  for (const file of files) {
    const raw = JSON.parse(fs.readFileSync(path.join(__dirname, file), 'utf-8'));
    totalTests += raw.tests.length;
    totalQuestions += raw.tests.reduce((sum, t) => sum + t.questions.length, 0);
    await uploadFile(file);
  }

  console.log(`\n🎉 DONE! Uploaded ${totalTests} tests, ${totalQuestions} questions across 3 exams (Batch 2).`);
  process.exit(0);
}

main().catch((err) => {
  console.error('❌ Upload failed:', err);
  process.exit(1);
});
