const express = require('express');

const { requireToken } = require('../middleware/auth');
const sync = require('../controllers/syncController');

const router = express.Router();

router.use(requireToken);
router.post('/push', sync.push);
router.get('/pull', sync.pull);
router.post('/reserve', sync.reserve);

module.exports = router;
