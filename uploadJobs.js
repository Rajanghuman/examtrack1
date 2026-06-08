const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');
const jobsData = require('./examtrack_jobs.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function uploadJobs() {
  const jobs = jobsData.jobs;
  let added = 0, updated = 0, unchanged = 0;

  console.log(`\n📋 Processing ${jobs.length} jobs...\n`);

  for (const job of jobs) {
    const jobId = job.id;
    const docRef = db.collection('jobs').doc(jobId);
    const existing = await docRef.get();

    if (!existing.exists) {
      await docRef.set(job);
      console.log(`✅ ADDED:   ${jobId}`);
      added++;
    } else {
      const oldData = existing.data();
      const oldStr = JSON.stringify(oldData);
      const newStr = JSON.stringify(job);

      if (oldStr !== newStr) {
        await docRef.set(job);
        console.log(`🔄 UPDATED: ${jobId}`);
        updated++;
      } else {
        console.log(`⏭️  NO CHANGE: ${jobId}`);
        unchanged++;
      }
    }
  }

  console.log('\n─────────────────────────────');
  console.log(`✅ Added:     ${added}`);
  console.log(`🔄 Updated:   ${updated}`);
  console.log(`⏭️  Unchanged: ${unchanged}`);
  console.log(`📋 Total:     ${jobs.length}`);
  console.log('─────────────────────────────\n');
  console.log('Upload complete!');
  process.exit(0);
}

uploadJobs().catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});