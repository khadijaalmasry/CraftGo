// Load environment variables
require('dotenv').config();
const jwt = require('jsonwebtoken');
const JWT_SECRET = (process.env.JWT_SECRET || 'super_secret_key_craftgo').trim();

console.log('JWT_SECRET used in middleware:', JWT_SECRET); // Debug

const verifyToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  console.log('Auth Header:', authHeader);

  const token = authHeader && authHeader.split(' ')[1];
  console.log('Token extracted:', token ? token.substring(0, 30) + '...' : 'null');

  if (!token) {
    console.log('No token provided');
    return res.status(401).json({
      error: 'Access denied. No token provided.'
    });
  }

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    console.log('Token verified, user:', decoded);
    req.user = decoded;
    next();
  } catch (err) {
    console.log('Invalid token:', err.message);
    return res.status(403).json({
      error: 'Invalid or expired token.'
    });
  }
};

const requireRole = (...roles) => {
  return (req, res, next) => {
    const granted = [req.user?.role, ...(req.user?.roles || [])].filter(Boolean);
    if (!req.user || !roles.some((role) => granted.includes(role))) {
      return res.status(403).json({
        error: `Access denied. Required role: ${roles.join(' or ')}.`
      });
    }
    next();
  };
};

// Optional auth: sets req.user if token is valid, but does NOT block if missing
const optionalAuth = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  if (token) {
    try {
      const decoded = jwt.verify(token, JWT_SECRET);
      req.user = decoded;
    } catch (err) {
      // Invalid token — treat as guest
      req.user = null;
    }
  } else {
    req.user = null;
  }
  next();
};

module.exports = {
  verifyToken,
  requireRole,
  optionalAuth,
};
