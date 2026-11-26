const { ObjectId } = require('mongodb');

const { getDb, SYNC_COLLECTIONS } = require('../config/db');
const backup = require('../services/backupService');

/** GET /api/admin/stats → record counts per collection + devices */
async function stats(req, res, next) {
  try {
    const db = getDb();
    const counts = {};
    for (const col of SYNC_COLLECTIONS) {
      counts[col] = await db.collection(col).countDocuments({ deleted: { $ne: true } });
    }
    const devices = await db.collection('devices').find({}).sort({ lastSeenAt: -1 }).toArray();
    const seq = await db.collection('counters').findOne({ _id: 'seq' });
    const meta = await db.collection('meta').findOne({ _id: 'backup' });
    res.json({ counts, devices, seq: seq ? seq.value : 0, lastBackup: meta || null });
  } catch (e) {
    next(e);
  }
}

/** GET /api/admin/backups */
async function listBackups(req, res, next) {
  try {
    res.json(await backup.listBackups());
  } catch (e) {
    next(e);
  }
}

/** POST /api/admin/backups → run a backup now */
async function runBackup(req, res, next) {
  try {
    const r = await backup.runBackup('manual');
    if (!r) return res.status(409).json({ error: 'A backup is already running' });
    return res.json(r);
  } catch (e) {
    return next(e);
  }
}

/** GET /api/admin/backups/:id → download .json.gz */
async function downloadBackup(req, res, next) {
  try {
    let id;
    try {
      id = new ObjectId(req.params.id);
    } catch {
      return res.status(400).json({ error: 'Invalid id' });
    }
    const files = await backup.listBackups();
    const f = files.find((x) => String(x.id) === String(id));
    if (!f) return res.status(404).json({ error: 'Backup not found' });
    res.setHeader('Content-Type', 'application/gzip');
    res.setHeader('Content-Disposition', `attachment; filename="${f.name}"`);
    return backup.downloadStream(id).on('error', next).pipe(res);
  } catch (e) {
    return next(e);
  }
}

module.exports = { stats, listBackups, runBackup, downloadBackup };
