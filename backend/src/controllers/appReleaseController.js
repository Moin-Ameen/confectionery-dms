const crypto = require('crypto');
const { GridFSBucket } = require('mongodb');

const { getDb } = require('../config/db');

const KEEP = 1; // keep only the newest APK (Atlas free tier has 512 MB)

function bucket() {
  return new GridFSBucket(getDb(), { bucketName: 'apk' });
}

/**
 * POST /api/app/release   (raw APK bytes as body)
 * Headers: X-Build: <int>, X-Version: <string>, X-Notes: <optional, url-encoded>
 * Called by GitHub Actions after every successful build.
 */
async function upload(req, res, next) {
  try {
    const build = parseInt(req.headers['x-build'], 10);
    const version = String(req.headers['x-version'] || '');
    const notes = decodeURIComponent(String(req.headers['x-notes'] || ''));
    const body = req.body;
    if (!Number.isFinite(build) || build <= 0) return res.status(400).json({ error: 'X-Build header required' });
    if (!Buffer.isBuffer(body) || body.length < 1024 * 100) return res.status(400).json({ error: 'APK body missing' });

    const sha256 = crypto.createHash('sha256').update(body).digest('hex');
    const b = bucket();
    const fileId = await new Promise((resolve, reject) => {
      const up = b.openUploadStream(`app-${build}.apk`, { metadata: { build, version, sha256 } });
      up.on('error', reject);
      up.on('finish', () => resolve(up.id));
      up.end(body);
    });

    await getDb()
      .collection('meta')
      .updateOne(
        { _id: 'app_release' },
        { $set: { build, version, notes, size: body.length, sha256, fileId, at: new Date() } },
        { upsert: true },
      );

    // delete older APKs
    const old = await b.find({ _id: { $ne: fileId } }).sort({ uploadDate: -1 }).skip(KEEP - 1).toArray();
    for (const f of old) await b.delete(f._id);

    console.log(`APK build ${build} (${version}) uploaded, ${body.length} bytes`);
    return res.json({ ok: true, build, version, size: body.length, sha256 });
  } catch (e) {
    return next(e);
  }
}

/** GET /api/app/latest → { build, version, notes, size, sha256, at } */
async function latest(req, res, next) {
  try {
    const m = await getDb().collection('meta').findOne({ _id: 'app_release' });
    if (!m) return res.json({ build: 0 });
    return res.json({ build: m.build, version: m.version, notes: m.notes || '', size: m.size, sha256: m.sha256, at: m.at });
  } catch (e) {
    return next(e);
  }
}

/** GET /api/app/download → the newest APK file */
async function download(req, res, next) {
  try {
    const m = await getDb().collection('meta').findOne({ _id: 'app_release' });
    if (!m) return res.status(404).json({ error: 'No APK uploaded yet' });
    res.setHeader('Content-Type', 'application/vnd.android.package-archive');
    res.setHeader('Content-Length', String(m.size));
    res.setHeader('Cache-Control', 'no-transform'); // keep Content-Length (no gzip) for the app's progress bar
    res.setHeader('Content-Disposition', `attachment; filename="ConfectioneryDistribution-${m.build}.apk"`);
    return bucket().openDownloadStream(m.fileId).on('error', next).pipe(res);
  } catch (e) {
    return next(e);
  }
}

module.exports = { upload, latest, download };
