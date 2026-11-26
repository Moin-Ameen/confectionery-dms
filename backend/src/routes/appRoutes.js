const express = require('express');

const { requireToken } = require('../middleware/auth');
const app = require('../controllers/appReleaseController');

const router = express.Router();

router.use(requireToken);
router.post('/release', express.raw({ type: '*/*', limit: '200mb' }), app.upload);
router.get('/latest', app.latest);
router.get('/download', app.download);

module.exports = router;
