const express = require('express');
const router = express.Router();
const deliveryController = require('../controllers/deliveryController');
const paymentController = require('../controllers/paymentController');
const {
    verifyToken
} = require('../middlewares/authMiddleware');

// ── Dashboard & Status ───────────────────────────────────────────────────────
router.get('/dashboard/:driverId', verifyToken, deliveryController.getDashboard);
router.patch('/status/:driverId', verifyToken, deliveryController.toggleAvailability);
router.post('/sos', verifyToken, deliveryController.triggerSOS);

// ── Delivery Orders ─────────────────────────────────────────────────────────
router.get('/orders/available', verifyToken, deliveryController.getAvailableOrders);
router.get('/drivers', verifyToken, deliveryController.getAvailableDrivers);
router.get('/orders/driver/:driverId', verifyToken, deliveryController.getDriverOrders);
router.get('/orders/:id', verifyToken, deliveryController.getOrderById);
// Orders for an artisan (craftsman)
router.get('/orders/artisan/:artisanId', verifyToken, deliveryController.getOrdersByArtisan);
router.post('/orders/:id/accept', verifyToken, deliveryController.acceptOrder);
router.patch('/orders/:id/status', verifyToken, deliveryController.updateOrderStatus);
router.post('/orders/:id/verify-pin', verifyToken, deliveryController.verifyDeliveryPinOrQR);
// Artisan assigns a driver to their delivery order
router.post('/orders/:id/assign-driver', verifyToken, deliveryController.assignDriverToOrder);
router.post('/orders/:id/cancel-by-artisan', verifyToken, deliveryController.cancelDeliveryOrderByArtisan);
router.patch('/orders/:id/clear-by-artisan', verifyToken, deliveryController.clearDeliveryOrderByArtisan);
router.post('/orders/:id/confirm-by-customer', verifyToken, deliveryController.confirmDeliveryByCustomer);

// ── Earnings & Financials ────────────────────────────────────────────────────
router.get('/earnings/:driverId', verifyToken, deliveryController.getEarnings);

// ── Vehicle Management ───────────────────────────────────────────────────────
router.get('/vehicle/:driverId', verifyToken, deliveryController.getVehicle);
router.put('/vehicle/:driverId', verifyToken, deliveryController.updateVehicle);

// ── Profile Management ───────────────────────────────────────────────────────
router.get('/profile/:driverId', verifyToken, deliveryController.getProfile);
router.put('/profile/:driverId', verifyToken, deliveryController.updateProfile);

// ── Notifications ───────────────────────────────────────────────────────────
router.get('/notifications/:userId', verifyToken, deliveryController.getUserNotifications);
router.patch('/notifications/:id/read', verifyToken, deliveryController.markAsRead);

// Stripe Connect onboarding for drivers (self or admin)
router.post('/onboard/:driverId', verifyToken, paymentController.createDriverOnboard);
router.post('/orders', verifyToken, deliveryController.createDeliveryOrder);
router.post('/payout/request', verifyToken, deliveryController.requestPayout);

// ── Delivery Reviews & Reports ───────────────────────────────────────────────
router.post('/orders/:id/review', verifyToken, deliveryController.reviewDeliveryOrder);
router.post('/orders/:id/report', verifyToken, deliveryController.reportDeliveryDriver);
router.get('/drivers/:driverId/reviews', verifyToken, deliveryController.getDriverReviews);

module.exports = router;