// uploadPunjabPolicePaper2.js
// Uploads Paper 2 (Punjabi Language Proficiency) chapters for Punjab Police
// to the existing studyMaterialChapters Firestore collection.
//
// Run from C:\examtrack:
//   node uploadPunjabPolicePaper2.js
//
// Prerequisites:
//   - serviceAccountKey.json in C:\examtrack (same one used for previous uploads)
//   - npm install firebase-admin (already installed)

const admin = require('firebase-admin');
const path  = require('path');
const fs    = require('fs');

// ── Firebase init ─────────────────────────────────────────────
const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
const db = admin.firestore();

// ── Load chapter data ─────────────────────────────────────────
const chaptersPath = path.join(__dirname, 'punjab_police_paper2_chapters.json');
const chapters = JSON.parse(fs.readFileSync(chaptersPath, 'utf8'));

console.log(`\nLoaded ${chapters.length} chapters for Punjab Police Paper 2`);
console.log('Collection: studyMaterialChapters');
console.log('ExamId: punjab-police-constable\n');

// ── Upload ────────────────────────────────────────────────────
async function upload() {
  const collection = db.collection('studyMaterialChapters');
  let uploaded = 0;
  let skipped  = 0;

  for (const chapter of chapters) {
    // Document ID: examId_subjectId_chapterId for uniqueness
    const docId = `${chapter.examId}_${chapter.subjectId}_${chapter.chapterId}`;

    try {
      await collection.doc(docId).set({
        ...chapter,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log(`  ✅ ${chapter.chapterOrder}. ${chapter.chapterTitle}`);
      uploaded++;
    } catch (err) {
      console.error(`  ❌ Failed: ${chapter.chapterTitle} — ${err.message}`);
      skipped++;
    }
  }

  console.log(`\n──────────────────────────────────────────`);
  console.log(`Uploaded : ${uploaded}`);
  console.log(`Failed   : ${skipped}`);
  console.log(`Total    : ${chapters.length}`);
  console.log(`──────────────────────────────────────────\n`);

  process.exit(0);
}

upload().catch(err => {
  console.error('Upload failed:', err);
  process.exit(1);
});
