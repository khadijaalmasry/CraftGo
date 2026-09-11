const express = require('express');
const router = express.Router();
const interactionController = require('../controllers/interactionController');
const {
    verifyToken
} = require('../middlewares/authMiddleware');

/**
 * @swagger
 * /api/interactions:
 *   post:
 *     summary: Log a user interaction with a product
 *     tags: [Interactions]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               productId:
 *                 type: string
 *               interactionType:
 *                 type: string
 *                 enum: [view, like, cart, purchase]
 */
router.post('/', verifyToken, interactionController.logInteraction);

/**
 * @swagger
 * /api/interactions:
 *   get:
 *     summary: Get all interactions for the logged in user
 *     tags: [Interactions]
 *     security:
 *       - bearerAuth: []
 */
router.get('/', verifyToken, interactionController.getUserInteractions);

/**
 * @swagger
 * /api/interactions/cart/clear:
 *   delete:
 *     summary: Clear the cart for the logged in user
 *     tags: [Interactions]
 *     security:
 *       - bearerAuth: []
 */
router.delete('/cart/clear', verifyToken, interactionController.clearCart);

/**
 * @swagger
 * /api/interactions/{id}:
 *   delete:
 *     summary: Delete a specific interaction
 *     tags: [Interactions]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Interaction deleted
 */
router.delete('/:id', verifyToken, interactionController.deleteInteraction);

/**
 * @swagger
 * /api/interactions/{id}:
 *   patch:
 *     summary: Update an interaction (e.g. quantity)
 *     tags: [Interactions]
 *     security:
 *       - bearerAuth: []
 */
router.patch('/:id', verifyToken, interactionController.updateInteraction);
router.post('/exhibition', verifyToken, interactionController.toggleExhibitionInterest);
router.get('/exhibitions', verifyToken, interactionController.getInterestedExhibitions);
module.exports = router;