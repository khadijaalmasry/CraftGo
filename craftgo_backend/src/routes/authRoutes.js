const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const profileController = require('../controllers/profileController');
const { verifyToken } = require('../middlewares/authMiddleware');
/**
 * @swagger
 * /api/auth/signup:
 *   post:
 *     summary: Register a new user
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               name:
 *                 type: string
 *               email:
 *                 type: string
 *               password:
 *                 type: string
 *               role:
 *                 type: string
 *                 enum: [customer, craftsman, exhibition_owner, admin]
 *               city:
 *                 type: string
 *     responses:
 *       201:
 *         description: User created successfully
 *       400:
 *         description: Email already in use
 */
router.post('/signup', authController.signup);

/**
 * @swagger
 * /api/auth/login:
 *   post:
 *     summary: Login a user
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               email:
 *                 type: string
 *               password:
 *                 type: string
 *     responses:
 *       200:
 *         description: Login successful
 *       401:
 *         description: Invalid credentials
 */
router.post('/login', authController.login);

/**
 * @swagger
 * /api/auth/send-otp:
 *   post:
 *     summary: Send OTP to email
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               email:
 *                 type: string
 *     responses:
 *       200:
 *         description: OTP sent successfully
 *       500:
 *         description: Failed to send OTP email
 */
router.post('/send-otp', authController.sendOtp);

/**
 * @swagger
 * /api/auth/verify-otp:
 *   post:
 *     summary: Verify OTP
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               email:
 *                 type: string
 *               otp:
 *                 type: string
 *     responses:
 *       200:
 *         description: OTP verified successfully
 *       400:
 *         description: Invalid OTP
 */
router.post('/verify-otp', authController.verifyOtp);

/**
 * @swagger
 * /api/auth/me:
 *   get:
 *     summary: Get current logged in user's profile
 *     tags: [Auth]
 *     security:
 *       - bearerAuth: []
 */
router.get('/me', verifyToken, profileController.getProfile);

// GET /api/auth/user/:id
// جلب البيانات العامة لمستخدم آخر
router.get(
  '/user/:id',
  verifyToken,
  profileController.getPublicUserProfile
);

/**
 * @swagger
 * /api/auth/profile:
 *   put:
 *     summary: Update current logged in user's profile
 *     tags: [Auth]
 *     security:
 *       - bearerAuth: []
 */
router.put('/profile', verifyToken, profileController.updateProfile);

module.exports = router;