// uploadStudyMaterial.js
//
// Uploads all study material chapters (SSC CGL, SSC CHSL, Punjab Police
// Constable) into the 'studyMaterialChapters' Firestore collection.
//
// Usage: place this file in your project root (same place as
// uploadJobs.js) alongside all_study_material_chapters.json, then run:
//   node uploadStudyMaterial.js
//
// Requires the same firebase-admin setup you already use for
// uploadJobs.js (a serviceAccountKey.json in the same folder, or
// however your existing script authenticates).

const admin = require('firebase-admin');
const fs = require('fs');

// ── Firebase Admin initialization ───────────────────────────────
// Reuses the same service account file path as your existing
// uploadJobs.js script. If your uploadJobs.js initializes Firebase
// differently, copy that exact initialization block here instead.
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// ── Load the chapter data ───────────────────────────────────────
const chapters = JSON.parse(
  fs.readFileSync('./all_study_material_chapters.json', 'utf8')
);

console.log(`Loaded ${chapters.length} chapters from JSON.`);

// ── Upload in batches (Firestore max 500 writes per batch) ──────
async function uploadAll() {
  const collectionRef = db.collection('studyMaterialChapters');
  const BATCH_SIZE = 400; // safely under the 500 limit

  let uploaded = 0;
  let created = 0;
  let updated = 0;

  for (let i = 0; i < chapters.length; i += BATCH_SIZE) {
    const batch = db.batch();
    const chunk = chapters.slice(i, i + BATCH_SIZE);

    for (const chapter of chunk) {
      // Document ID: combine examId + chapterId for a stable,
      // human-readable, guaranteed-unique key (avoids accidental
      // duplicate documents if this script is run more than once).
      const docId = `${chapter.examId}__${chapter.chapterId}`;
      const docRef = collectionRef.doc(docId);

      batch.set(docRef, {
        ...chapter,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    uploaded += chunk.length;
    console.log(`Uploaded batch: ${uploaded}/${chapters.length} chapters`);
  }

  console.log('\n✅ Upload complete.');
  console.log(`Total chapters uploaded: ${uploaded}`);

  // Print a per-exam summary
  const examCounts = {};
  for (const c of chapters) {
    examCounts[c.examId] = (examCounts[c.examId] || 0) + 1;
  }
  console.log('\nPer-exam breakdown:');
  for (const [examId, count] of Object.entries(examCounts)) {
    console.log(`  ${examId}: ${count} chapters`);
  }
}

uploadAll()
  .then(() => {
    console.log('\nDone. You can verify the data in the Firebase Console under:');
    console.log('Firestore Database → studyMaterialChapters collection');
    process.exit(0);
  })
  .catch((err) => {
    console.error('❌ Upload failed:', err);
    process.exit(1);
  });
