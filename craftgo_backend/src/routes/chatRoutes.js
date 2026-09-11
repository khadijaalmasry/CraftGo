const express = require('express');
const router = express.Router();
const chatController = require('../controllers/chatController');
const { verifyToken } = require('../middlewares/authMiddleware');

/**
 * @swagger
 * /api/chats:
 *   post:
 *     summary: Create or retrieve a chat between current user (customer) and a craftsman
 *     tags: [Chat]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [craftsmanId]
 *             properties:
 *               craftsmanId:
 *                 type: string
 *               orderId:
 *                 type: string
 */
router.post('/', verifyToken, chatController.createOrGetChat);

/**
 * @swagger
 * /api/chats:
 *   get:
 *     summary: Get all chats for the logged-in user
 *     tags: [Chat]
 *     security:
 *       - bearerAuth: []
 */
router.get('/', verifyToken, chatController.getMyChats);

/**
 * @swagger
 * /api/chats/{chatId}/messages:
 *   get:
 *     summary: Get messages for a chat (must be a member)
 *     tags: [Chat]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: chatId
 *         required: true
 *         schema:
 *           type: string
 */
router.get('/:chatId/messages', verifyToken, chatController.getMessages);

/**
 * @swagger
 * /api/chats/{chatId}/messages:
 *   post:
 *     summary: Send a message to a chat (must be a member)
 *     tags: [Chat]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: chatId
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [content]
 *             properties:
 *               content:
 *                 type: string
 */
router.post('/:chatId/messages', verifyToken, chatController.sendMessage);

/**
 * @swagger
 * /api/chats/{chatId}/read:
 *   patch:
 *     summary: Mark all unread messages in a chat as read
 *     tags: [Chat]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: chatId
 *         required: true
 *         schema:
 *           type: string
 */
router.patch('/:chatId/read', verifyToken, chatController.markAsRead);

module.exports = router;