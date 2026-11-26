const { getDb, SYNC_COLLECTIONS, NUMBERED_COLLECTIONS } = require('../config/db');
const { maybeRunDailyBackup } = require('../services/backupService');

const PULL_LIMIT = 2000;
const MAX_RESERVE = 500;

/**
 * Seq ranges reserved by pushes that are still writing. A pull never returns (or skips past)
 * a seq at or above the lowest in-flight start, otherwise a slower push could be missed forever.
 * Works for a single server instance (one Render web service).
 */
const inFlight = new Map(); // token -> first seq
let flightId = 0;

function safeSeq() {
  if (inFlight.size === 0) return Number.MAX_SAFE_INTEGER;
  return Math.min(...inFlight.values()) - 1;
}

/** Reserve `count` global sequence numbers atomically. Returns the first one. */
async function reserveSeq(count) {
  const r = await getDb()
    .collection('counters')
    .findOneAndUpdate({ _id: 'seq' }, { $inc: { value: count } }, { upsert: true, returnDocument: 'after' });
  return r.value - count + 1;
}

async function touchDevice(deviceId, field) {
  if (!deviceId) return;
  await getDb()
    .collection('devices')
    .updateOne(
      { _id: deviceId },
      { $set: { lastSeenAt: new Date(), [field]: new Date() }, $setOnInsert: { firstSeenAt: new Date() } },
      { upsert: true },
    );
}

/**
 * POST /api/sync/push
 * body: { deviceId, changes: [{ col, id, data, deleted, updatedAt }] }
 * Last write (by arrival) wins. Every stored change gets a global `seq` used by pull.
 */
async function push(req, res, next) {
  try {
    const { deviceId = '', changes = [] } = req.body || {};
    if (!Array.isArray(changes)) return res.status(400).json({ error: 'changes must be an array' });
    const valid = changes.filter(
      (c) => c && SYNC_COLLECTIONS.includes(c.col) && typeof c.id === 'string' && c.id.length > 0,
    );
    if (valid.length === 0) {
      await touchDevice(deviceId, 'lastPushAt');
      return res.json({ ok: true, saved: 0 });
    }

    const flight = ++flightId;
    inFlight.set(flight, Number.MAX_SAFE_INTEGER); // block pulls while the range is being reserved
    let seq;
    try {
      seq = await reserveSeq(valid.length);
    } catch (e) {
      inFlight.delete(flight);
      throw e;
    }
    inFlight.set(flight, seq);
    const byCol = {};
    const now = new Date();
    for (const c of valid) {
      (byCol[c.col] = byCol[c.col] || []).push({
        updateOne: {
          filter: { _id: c.id },
          update: {
            $set: {
              data: c.data && typeof c.data === 'object' ? c.data : { id: c.id },
              deleted: c.deleted === true,
              seq: seq++,
              deviceId,
              clientUpdatedAt: Number(c.updatedAt) || 0,
              updatedAt: now,
            },
          },
          upsert: true,
        },
      });
    }
    const db = getDb();
    try {
      await Promise.all(
        Object.entries(byCol).map(([col, ops]) => db.collection(col).bulkWrite(ops, { ordered: false })),
      );
    } finally {
      inFlight.delete(flight);
    }
    await touchDevice(deviceId, 'lastPushAt');
    maybeRunDailyBackup(); // fallback when the cron missed (e.g. server was asleep)
    return res.json({ ok: true, saved: valid.length });
  } catch (e) {
    return next(e);
  }
}

/**
 * GET /api/sync/pull?since=<seq>&deviceId=<id>
 * → { serverTime, changes: [{ col, id, data, deleted }], hasMore }
 * `serverTime` is the last seq returned; the app sends it back as `since` next time.
 */
async function pull(req, res, next) {
  try {
    const since = Number(req.query.since) || 0;
    const deviceId = String(req.query.deviceId || '');
    const db = getDb();

    const safe = safeSeq();
    const filter = { seq: { $gt: since, $lte: safe } };
    if (deviceId) filter.deviceId = { $ne: deviceId }; // own changes are already on the phone

    const perCol = await Promise.all(
      SYNC_COLLECTIONS.map(async (col) => {
        const docs = await db
          .collection(col)
          .find(filter, { projection: { data: 1, deleted: 1, seq: 1 } })
          .sort({ seq: 1 })
          .limit(PULL_LIMIT + 1)
          .toArray();
        return docs.map((d) => ({ col, id: d._id, data: d.data, deleted: d.deleted === true, seq: d.seq }));
      }),
    );

    let all = perCol.flat().sort((a, b) => a.seq - b.seq);
    const hasMore = all.length > PULL_LIMIT;
    if (hasMore) all = all.slice(0, PULL_LIMIT);

    let serverTime = since;
    if (all.length) {
      serverTime = all[all.length - 1].seq;
    } else {
      // nothing new for this device: jump to the current global seq
      const c = await db.collection('counters').findOne({ _id: 'seq' });
      serverTime = Math.max(since, Math.min(c ? c.value : 0, safe));
    }
    await touchDevice(deviceId, 'lastPullAt');
    return res.json({
      serverTime,
      hasMore,
      changes: all.map(({ col, id, data, deleted }) => ({ col, id, data, deleted })),
    });
  } catch (e) {
    return next(e);
  }
}

/**
 * POST /api/sync/reserve  body: { deviceId, col, count }
 * Gives this phone a block of unique numbers (order / bill / voucher no.) so phones never clash offline.
 * → { col, from, to }
 */
async function reserve(req, res, next) {
  try {
    const { col, deviceId = '' } = req.body || {};
    const count = Math.min(Math.max(parseInt(req.body?.count, 10) || 50, 1), MAX_RESERVE);
    if (!NUMBERED_COLLECTIONS.includes(col)) return res.status(400).json({ error: 'Unknown collection' });
    const db = getDb();
    const counters = db.collection('counters');
    const key = `no:${col}`;

    // never hand out a number already used (e.g. data created before the server existed)
    const top = await db
      .collection(col)
      .find({}, { projection: { 'data.no': 1 } })
      .sort({ 'data.no': -1 })
      .limit(1)
      .toArray();
    const maxUsed = Number(top[0]?.data?.no) || 0;
    await counters.updateOne({ _id: key }, { $max: { value: maxUsed } }, { upsert: true });

    const r = await counters.findOneAndUpdate(
      { _id: key },
      { $inc: { value: count } },
      { upsert: true, returnDocument: 'after' },
    );
    const to = r.value;
    const from = to - count + 1;
    await db.collection('reservations').insertOne({ col, deviceId, from, to, at: new Date() });
    return res.json({ col, from, to });
  } catch (e) {
    return next(e);
  }
}

module.exports = { push, pull, reserve };
