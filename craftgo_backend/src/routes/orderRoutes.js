const express = require('express');
const router = express.Router();
const orderController = require('../controllers/orderController');
const {
    verifyToken
} = require('../middlewares/authMiddleware');

/**
 * @swagger
 * /api/orders:
 *   post:
 *     summary: Place a new order
 *     tags: [Orders]
 *     security:
 *       - bearerAuth: []
 */
router.post('/', verifyToken, orderController.createOrder);

/**
 * @swagger
 * /api/orders/customer:
 *   get:
 *     summary: Get all orders for the logged in customer
 *     tags: [Orders]
 *     security:
 *       - bearerAuth: []
 */
router.get('/customer', verifyToken, orderController.getOrdersByUser);

/**
 * @swagger
 * /api/orders/artisan:
 *   get:
 *     summary: Get all orders for the currently logged in artisan
 *     tags: [Orders]
 *     security:
 *       - bearerAuth: []
 */
router.get('/artisan', verifyToken, orderController.getOrdersForCurrentArtisan);

/**
 * @swagger
 * /api/orders/craftsman/{craftsmanId}:
 *   get:
 *     summary: Get all orders for a craftsman's products
 *     tags: [Orders]
 *     security:
 *       - bearerAuth: []
 */
router.get('/craftsman/:craftsmanId', verifyToken, orderController.getOrdersByCraftsman);

/**
 * @swagger
 * /api/orders/{id}:
 *   get:
 *     summary: Get a single order by ID
 *     tags: [Orders]
 *     security:
 *       - bearerAuth: []
 */
router.get('/:id', verifyToken, orderController.getOrderById);

/**
 * @swagger
 * /api/orders/{id}/status:
 *   patch:
 *     summary: Update order status (craftsman or admin only)
 *     tags: [Orders]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               status:
 *                 type: string
 *                 enum: [pending, accepted, in_progress, completed, cancelled]
 */
router.patch('/:id/status', verifyToken, orderController.updateOrderStatus);
router.delete('/:id', verifyToken, orderController.deleteOrder);

module.exports = router;