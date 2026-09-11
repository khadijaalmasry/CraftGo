const express = require('express');
const router = express.Router();
const adminController = require('../controllers/adminController');
const disputeController = require('../controllers/disputeController');
const {
  verifyToken,
  requireRole
} = require('../middlewares/authMiddleware');
const exhibitionController = require('../controllers/exhibitionController');
// ─────────────────────────────────────────────────────────────
// Admin Login (Public)
// ─────────────────────────────────────────────────────────────

router.post(
  '/login/request-otp',
  adminController.requestAdminLoginOtp
);

router.post(
  '/login/verify-otp',
  adminController.verifyAdminLoginOtp
);
/**
 * @swagger
 * /api/admin/stats:
 *   get:
 *     summary: Get overall platform statistics (For Admins)
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Success
 */
router.get('/stats', verifyToken, requireRole('admin'), adminController.getStats);

/**
 * @swagger
 * /api/admin/reports/craftsman/{craftsmanId}:
 *   get:
 *     summary: Get sales and order report for a specific craftsman (Admin or Craftsman)
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: craftsmanId
 *         required: true
 *         schema:
 *           type: string
 *       - in: query
 *         name: period
 *         schema:
 *           type: string
 *           enum: [monthly, yearly, all]
 *         description: Report period
 *     responses:
 *       200:
 *         description: Success
 */
router.get(
  '/reports/craftsman/:craftsmanId',
  verifyToken,
  requireRole('admin', 'craftsman'),
  (req, res, next) => {
    if (req.user.role === 'craftsman' && req.user.id !== req.params.craftsmanId) {
      return res.status(403).json({
        error: 'Forbidden: You can only view your own report'
      });
    }
    next();
  },
  adminController.getCraftsmanReport
);

// ── Artisan Verification ──────────────────────────────────────────────────

/**
 * GET /api/admin/pending-artisans
 * Returns all artisans with isVerified = false
 */
router.get(
  '/pending-artisans',
  verifyToken,
  requireRole('admin'),
  adminController.getPendingArtisans
);

/**
 * PATCH /api/admin/artisans/:artisanProfileId/review
 * body: { action: 'approve' | 'reject' }
 */
router.patch(
  '/artisans/:artisanProfileId/review',
  verifyToken,
  requireRole('admin'),
  adminController.reviewArtisan
);

// Admin exhibition management (mirror of /api/exhibitions admin endpoints)
router.get(
  '/exhibitions',
  verifyToken,
  requireRole('admin'),
  exhibitionController.getAdminExhibitions
);

router.get(
  '/exhibitions/analytics',
  verifyToken,
  requireRole('admin'),
  exhibitionController.getAdminAnalytics
);

router.patch(
  '/exhibitions/:id/feature',
  verifyToken,
  requireRole('admin'),
  exhibitionController.toggleFeatured
);

router.patch(
  '/exhibitions/:id/status',
  verifyToken,
  requireRole('admin'),
  exhibitionController.adminOverrideStatus
);

router.post(
  '/exhibitions/:id/approve',
  verifyToken,
  requireRole('admin'),
  exhibitionController.approveExhibition
);

router.post(
  '/exhibitions/:id/reject',
  verifyToken,
  requireRole('admin'),
  exhibitionController.rejectExhibition
);

// ── Order Dispute Management ──────────────────────────────────────────────────

// GET /api/admin/disputes — list all disputes (filter by ?status=pending etc.)
router.get(
  '/disputes',
  verifyToken,
  requireRole('admin'),
  disputeController.getAdminDisputes
);

// GET /api/admin/disputes/:id — view a single dispute with full audit trail
router.get(
  '/disputes/:id',
  verifyToken,
  requireRole('admin'),
  disputeController.getDisputeById
);

// PATCH /api/admin/disputes/:id/resolve — admin resolves a dispute
router.patch(
  '/disputes/:id/resolve',
  verifyToken,
  requireRole('admin'),
  disputeController.resolveDispute
);

// ── User Management Endpoints ───────────────────────────────────────────────
router.get('/users', verifyToken, requireRole('admin'), adminController.getUsers);
router.patch('/users/:id/status', verifyToken, requireRole('admin'), adminController.toggleUserStatus);
router.post('/users/:id/promote', verifyToken, requireRole('admin'), adminController.promoteToAdmin);
router.delete('/users/:id', verifyToken, requireRole('admin'), adminController.deleteUser);

module.exports = router;