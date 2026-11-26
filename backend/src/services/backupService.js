const zlib = require('zlib');
const { GridFSBucket } = require('mongodb');
const cron = require('node-cron');

const { getDb, SYNC_COLLECTIONS } = require('../config/db');

const KEEP = Number(process.env.BACKUP_KEEP || 7);
let running = false;
let lastCheck = 0;

function bucket() {
  return new GridFSBucket(getDb(), { bucketName: 'backups' });
}

/** Full snapshot of all synced collections → gzip JSON in GridFS. Keeps the last KEEP backups. */
async function runBackup(trigger = 'manual') {
  if (running) return null;
  running = true;
  try {
    const db = getDb();
    const snapshot = { createdAt: new Date().toISOString(), db: db.databaseName, collections: {} };
    for (const col of SYNC_COLLECTIONS) {
      snapshot.collections[col] = await db.collection(col).find({}).toArray();
    }
    const gz = zlib.gzipSync(Buffer.from(JSON.stringify(snapshot)));
    const name = `backup-${snapshot.createdAt.replace(/[:.]/g, '-')}.json.gz`;
    const b = bucket();
    const id = await new Promise((resolve, reject) => {
      const up = b.openUploadStream(name, { metadata: { trigger, size: gz.length } });
      up.on('error', reject);
      up.on('finish', () => resolve(up.id));
      up.end(gz);
    });

    // keep only the newest KEEP files
    const old = await b.find({}).sort({ uploadDate: -1 }).skip(KEEP).toArray();
    for (const f of old) await b.delete(f._id);

    await db.collection('meta').updateOne(
      { _id: 'backup' },
      { $set: { lastAt: new Date(), lastName: name } },
      { upsert: true },
    );
    console.log(`Backup saved: ${name} (${gz.length} bytes, ${trigger})`);
    return { id, name, size: gz.length };
  } finally {
    running = false;
  }
}

/** Called on sync traffic: runs a backup if the last one is older than 24h (covers missed cron). */
function maybeRunDailyBackup() {
  const now = Date.now();
  if (now - lastCheck < 60 * 60 * 1000) return; // check at most hourly
  lastCheck = now;
  getDb()
    .collection('meta')
    .findOne({ _id: 'backup' })
    .then((m) => {
      if (!m || now - new Date(m.lastAt).getTime() > 24 * 60 * 60 * 1000) return runBackup('auto');
      return null;
    })
    .catch((e) => console.error('Backup check failed:', e.message));
}

function scheduleDailyBackup() {
  // 02:30 every night, Pakistan time
  cron.schedule('30 2 * * *', () => runBackup('cron').catch((e) => console.error('Backup failed:', e)), {
    timezone: 'Asia/Karachi',
  });
}

async function listBackups() {
  const files = await bucket().find({}).sort({ uploadDate: -1 }).toArray();
  return files.map((f) => ({ id: f._id, name: f.filename, size: f.length, at: f.uploadDate, trigger: f.metadata?.trigger }));
}

function downloadStream(id) {
  return bucket().openDownloadStream(id);
}

module.exports = { runBackup, maybeRunDailyBackup, scheduleDailyBackup, listBackups, downloadStream };
