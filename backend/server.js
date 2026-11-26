require('dotenv').config();

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');

const { connectDb } = require('./src/config/db');
const syncRoutes = require('./src/routes/syncRoutes');
const adminRoutes = require('./src/routes/adminRoutes');
const appRoutes = require('./src/routes/appRoutes');
const { scheduleDailyBackup } = require('./src/services/backupService');

const PORT = process.env.PORT || 5000;

async function main() {
  if (!process.env.MONGODB_URI) throw new Error('MONGODB_URI is not set');
  if (!process.env.API_TOKEN) throw new Error('API_TOKEN is not set');

  await connectDb();

  const app = express();
  app.set('trust proxy', 1);
  app.use(helmet());
  app.use(cors());
  app.use(compression());
  // APK upload uses a raw body parser (mounted before the JSON parser)
  app.use('/api/app', appRoutes);
  app.use(express.json({ limit: '15mb' }));
  if (process.env.NODE_ENV !== 'production') app.use(morgan('dev'));

  app.get('/', (req, res) => res.json({ name: 'Confectionery DMS API', status: 'ok' }));
  app.get('/api/health', (req, res) => res.json({ ok: true, time: Date.now() }));

  app.use('/api/sync', syncRoutes);
  app.use('/api/admin', adminRoutes);

  app.use((req, res) => res.status(404).json({ error: 'Not found' }));
  // eslint-disable-next-line no-unused-vars
  app.use((err, req, res, next) => {
    console.error(err);
    res.status(err.status || 500).json({ error: err.expose ? err.message : 'Server error' });
  });

  app.listen(PORT, () => console.log(`API listening on :${PORT}`));
  scheduleDailyBackup();
}

main().catch((e) => {
  console.error('Failed to start:', e);
  process.exit(1);
});
