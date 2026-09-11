const express = require('express');
const router = express.Router();
const adminDeliveryController = require('../controllers/adminDeliveryController');
const { verifyToken, requireRole } = require('../middlewares/authMiddleware');

// All routes require admin token
router.use(verifyToken);
router.use(requireRole('admin'));

// Stats
router.get('/stats', adminDeliveryController.getDeliveryStats);

// Delivery Orders
router.get('/orders', adminDeliveryController.getDeliveryOrders);
router.patch('/orders/:id/assign', adminDeliveryController.assignDriverToOrder);
router.patch('/orders/:id/cancel', adminDeliveryController.cancelDeliveryOrder);
router.patch('/orders/:id/status', adminDeliveryController.updateDeliveryOrderStatus);

// Drivers / Delivery Fleet
router.get('/drivers', adminDeliveryController.getDeliveryDrivers);
router.get('/drivers/:id', adminDeliveryController.getDriverDetails);
router.patch('/drivers/:id/verify', adminDeliveryController.verifyDriver);
router.patch('/drivers/:id/suspend', adminDeliveryController.suspendDriver);

// Issues & SOS Alerts
router.get('/issues', adminDeliveryController.getDeliveryIssues);
router.patch('/issues/:id/resolve', adminDeliveryController.resolveIssue);
router.patch('/issues/:id/dismiss', adminDeliveryController.dismissIssue);

module.exports = router;
