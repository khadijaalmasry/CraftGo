const express = require('express');
const router = express.Router();
const exhibitionController = require('../controllers/exhibitionController');
const {
  verifyToken
} = require('../middlewares/authMiddleware');
const {
  requireRole
} = require('../middlewares/authMiddleware');

// ── Public ──────────────────────────────────────────────────────────────────

/**
 * GET /api/exhibitions
 * List all exhibitions (browsable without login)
 */
router.get('/', exhibitionController.getAllExhibitions);

// ── Owner-scoped ─────────────────────────────────────────────────────────────

/**
 * GET /api/exhibitions/owner/:ownerId
 * Get all exhibitions created by a specific exhibition owner
 * Used by the owner's management dashboard
 */
router.get('/owner/:ownerId', verifyToken, exhibitionController.getOwnerExhibitions);

// ── Craftsman-scoped ─────────────────────────────────────────────────────────

/**
 * GET /api/exhibitions/craftsman/:craftsmanId
 * Get all exhibition registrations for a craftsman (their own history)
 * Returns registration rows with joined Exhibition data
 */
router.get('/craftsman/:craftsmanId', verifyToken, exhibitionController.getCraftsmanRegistrations);

// ── Single Exhibition ────────────────────────────────────────────────────────

/**
 * GET /api/exhibitions/:exhibitionId
 * Get full details of one exhibition, including all registered craftsmen
 */
router.get('/:exhibitionId', exhibitionController.getExhibitionById);

/**
 * POST /api/exhibitions
 * Create a new exhibition (exhibition owners only)
 * Body: { ownerId, name, description, location, capacity, categoryCapacities, startDate, endDate, boothLayout }
 */
router.post('/', verifyToken, exhibitionController.createExhibition);

/**
 * POST /api/exhibitions/:exhibitionId/register
 * Register a craftsman to an exhibition with booth + payment info
 * Body: { craftsmanId, craftCategory, boothId, boothPrice, hasPaid, paymentReference }
 * Response: { status: 'confirmed' | 'standby', standbyRank?, registration }
 */
router.get('/:exhibitionId/register', verifyToken, exhibitionController.getCraftsmanRegistrationForExhibition);
router.post('/:exhibitionId/register', verifyToken, exhibitionController.registerForExhibition);
router.post('/:exhibitionId/invite/:craftsmanId', verifyToken, exhibitionController.inviteCraftsman);

/**
 * PATCH /api/exhibitions/:exhibitionId/registrations/:registrationId/status
 * Exhibition owner accepts or rejects a pending craftsman registration
 * Body: { status: 'confirmed' | 'rejected', boothId? }
 */
router.patch(
  '/:exhibitionId/registrations/:registrationId/status',
  verifyToken,
  exhibitionController.updateRegistrationStatus
);

/**
 * POST /api/exhibitions/:exhibitionId/registrations/:registrationId/absence
 * Craftsman reports they cannot attend
 * Body: { reason, apologyText }
 * → Cancels their registration
 * → Auto-promotes next standby craftsman (lowest standbyRank)
 */
router.post(
  '/:exhibitionId/registrations/:registrationId/absence',
  verifyToken,
  exhibitionController.reportAbsence
);

/**
 * PUT /api/exhibitions/:exhibitionId
 * Update exhibition details
 */
router.put('/:exhibitionId', verifyToken, exhibitionController.updateExhibition);

/**
 * DELETE /api/exhibitions/:exhibitionId
 * Delete exhibition
 */
router.delete('/:exhibitionId', verifyToken, exhibitionController.deleteExhibition);

/**
 * PUT /api/exhibitions/:exhibitionId/capacity
 * Update exhibition overall and category capacities
 */
router.put('/:exhibitionId/capacity', verifyToken, exhibitionController.updateCapacity);

/**
 * PUT /api/exhibitions/:exhibitionId/booth-layout
 * Update exhibition booth layout
 */
router.put('/:exhibitionId/booth-layout', verifyToken, exhibitionController.updateBoothLayout);

// ── Add these routes after the existing ones ─────────────────────────

/**
 * GET /api/exhibitions/:exhibitionId/attendance
 * Get attendance records for all dates of an exhibition
 */
router.get('/:exhibitionId/attendance', verifyToken, exhibitionController.getAttendance);

/**
 * POST /api/exhibitions/:exhibitionId/attendance
 * Update attendance for a specific craftsman on a specific date
 * Body: { craftsmanId, date, isPresent, absenceReason? }
 */
router.post('/:exhibitionId/attendance', verifyToken, exhibitionController.updateAttendance);

/**
 * POST /api/exhibitions/:exhibitionId/attendance/promote
 * Promote a standby craftsman for a specific day
 * Body: { standbyCraftsmanId, boothId, date }
 */
router.post('/:exhibitionId/attendance/promote', verifyToken, exhibitionController.promoteStandby);

/**
 * GET /api/admin/exhibitions
 * Admin: get all exhibitions with filters
 */
router.get(
  '/admin/exhibitions',
  verifyToken,
  requireRole('admin'),
  exhibitionController.getAdminExhibitions
);

/**
 * GET /api/admin/exhibitions/analytics
 * Admin: get platform analytics
 */
router.get(
  '/admin/exhibitions/analytics',
  verifyToken,
  requireRole('admin'),
  exhibitionController.getAdminAnalytics
);

/**
 * PATCH /api/admin/exhibitions/:id/feature
 * Admin: toggle featured status
 */
router.patch(
  '/admin/exhibitions/:id/feature',
  verifyToken,
  requireRole('admin'),
  exhibitionController.toggleFeatured
);

/**
 * PATCH /api/admin/exhibitions/:id/status
 * Admin: override exhibition status (suspend/reactivate)
 */
router.patch(
  '/admin/exhibitions/:id/status',
  verifyToken,
  requireRole('admin'),
  exhibitionController.adminOverrideStatus
);

/**
 * POST /api/admin/exhibitions/:id/approve
 * Admin: approve a pending exhibition
 */
router.post(
  '/admin/exhibitions/:id/approve',
  verifyToken,
  requireRole('admin'),
  exhibitionController.approveExhibition
);

/**
 * POST /api/admin/exhibitions/:id/reject
 * Admin: reject a pending exhibition with reason
 */
router.post(
  '/admin/exhibitions/:id/reject',
  verifyToken,
  requireRole('admin'),
  exhibitionController.rejectExhibition
);

module.exports = router;