const crypto = require('crypto');

/** Bearer token check. The same API_TOKEN is entered in the app: Settings → Server. */
function requireToken(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7).trim() : '';
  const expected = process.env.API_TOKEN || '';
  const a = Buffer.from(token);
  const b = Buffer.from(expected);
  if (!expected || a.length !== b.length || !crypto.timingSafeEqual(a, b)) {
    return res.status(401).json({ error: 'Invalid API token' });
  }
  return next();
}

module.exports = { requireToken };
