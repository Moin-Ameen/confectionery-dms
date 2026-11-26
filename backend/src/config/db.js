const { MongoClient } = require('mongodb');

/** Collections the app syncs (must match lib/services/local_db.dart → Col). */
const SYNC_COLLECTIONS = [
  'users', 'companies', 'products', 'stock_moves', 'purchases', 'routes', 'shops', 'schemes', 'orders',
  'load_sheets', 'returns', 'recoveries', 'recovery_slips', 'accounts', 'vouchers', 'pings', 'activity_logs',
];

/** Collections whose `no` field is a running number reserved from the server. */
const NUMBERED_COLLECTIONS = ['orders', 'purchases', 'load_sheets', 'returns', 'vouchers'];

let client;
let db;

async function connectDb() {
  client = new MongoClient(process.env.MONGODB_URI, { maxPoolSize: 20 });
  await client.connect();
  db = client.db(process.env.DB_NAME || 'confectionery_dms');

  // indexes
  for (const name of SYNC_COLLECTIONS) {
    await db.collection(name).createIndex({ seq: 1 });
    await db.collection(name).createIndex({ deviceId: 1, seq: 1 });
  }
  for (const name of NUMBERED_COLLECTIONS) {
    await db.collection(name).createIndex({ 'data.no': -1 });
  }
  await db.collection('devices').createIndex({ lastSeenAt: -1 });
  console.log(`MongoDB connected: ${db.databaseName}`);
  return db;
}

function getDb() {
  if (!db) throw new Error('DB not connected');
  return db;
}

module.exports = { connectDb, getDb, SYNC_COLLECTIONS, NUMBERED_COLLECTIONS };
