const express = require('express');

const { requireToken } = require('../middleware/auth');
const admin = require('../controllers/adminController');

const router = express.Router();

router.use(requireToken);
router.get('/stats', admin.stats);
router.get('/backups', admin.listBackups);
router.post('/backups', admin.runBackup);
router.get('/backups/:id', admin.downloadBackup);

module.exports = router;
