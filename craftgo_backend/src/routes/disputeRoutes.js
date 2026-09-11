const express = require('express');
const router = express.Router();
const disputeController = require('../controllers/disputeController');
const {
    verifyToken,
    requireRole
} = require('../middlewares/authMiddleware');

// ── User routes ────────────────────────────────────────────────────────────
router.post('/', verifyToken, disputeController.submitDispute);
router.get('/', verifyToken, disputeController.getMyDisputes); // ← ADDED
router.get('/my', verifyToken, disputeController.getMyDisputes); // existing

// ── Admin routes ──────────────────────────────────────────────────────────
router.get('/admin/disputes', verifyToken, requireRole('admin'), disputeController.getAdminDisputes);
router.get('/admin/disputes/:id', verifyToken, requireRole('admin'), disputeController.getDisputeById);
router.patch('/admin/disputes/:id/resolve', verifyToken, requireRole('admin'), disputeController.resolveDispute);

module.exports = router;