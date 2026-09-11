const express = require('express');
const router = express.Router();
const aiController = require('../controllers/aiController');
const {
  verifyToken,
  requireRole,
} = require('../middlewares/authMiddleware');

/**
 * @swagger
 * /api/ai/generate-apology:
 *   post:
 *     summary: Generate a professional apology letter using AI
 *     tags: [AI Services]
 */
router.post('/generate-apology', verifyToken, aiController.generateApology);

/**
 * @swagger
 * /api/ai/match-standby/{exhibitionId}:
 *   get:
 *     summary: AI match the best replacement from standby list
 *     tags: [AI Services]
 */
router.get('/match-standby/:exhibitionId', verifyToken, aiController.matchStandby);

/**
 * @swagger
 * /api/ai/validate-bio:
 *   post:
 *     summary: Validate a craftsman's bio for professionalism using AI
 *     tags: [AI Services]
 */
router.post('/validate-bio', aiController.validateBio);

/**
 * @swagger
 * /api/ai/suggest-capacities:
 *   post:
 *     summary: Suggest capacity distribution based on exhibition description
 *     tags: [AI Services]
 */
router.post('/suggest-capacities', verifyToken, aiController.suggestCapacities);

/**
 * @swagger
 * /api/ai/analyze-demand:
 *   post:
 *     summary: Analyze real market demand using interaction data from DB
 *     tags: [AI Services]
 */
router.post('/analyze-demand', verifyToken, aiController.analyzeDemand);

/**
 * @swagger
 * /api/ai/screen-candidates:
 *   post:
 *     summary: Screen and rank craftsmen applying for a specific category
 *     tags: [AI Services]
 */
router.post('/screen-candidates', verifyToken, aiController.screenCandidates);

/**
 * @swagger
 * /api/ai/analyze-order:
 *   post:
 *     summary: Analyze a custom order request using AI — suggests category, price range, and suitable artisans
 *     tags: [AI Services]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               text:
 *                 type: string
 *                 description: Customer's textual description of the product they want
 *               hasImage:
 *                 type: boolean
 *                 description: Whether a reference image was uploaded
 *               hasDrawing:
 *                 type: boolean
 *                 description: Whether the customer provided a hand drawing
 *               imageDescription:
 *                 type: string
 *                 description: AI-extracted description of the uploaded image (optional)
 *     responses:
 *       200:
 *         description: AI analysis result with category, price range, artisans, and products
 */
router.post('/analyze-order', aiController.analyzeOrder);

/**
 * @swagger
 * /api/ai/generate-bio:
 *   post:
 *     summary: Generate a professional bio for a craftsman using AI
 *     tags: [AI Services]
 */
router.post('/generate-bio', aiController.generateBio);
/**
 * @swagger
 * /api/ai/product-assistant:
 * 
 *   post:
 *     summary: Generate product description, pricing, tags, score, and recommendations
 *     tags: [AI Services]
 */
router.post(
  '/enhance-product-image',
  verifyToken,
  requireRole('artisan'),
  aiController.enhanceProductImage
);
router.post(
  '/product-assistant',
  verifyToken,
  aiController.productAssistant
);

/**
 * @swagger
 * /api/ai/improve-description:
 *   post:
 *     summary: Improve product description using AI
 *     tags: [AI Services]
 */
router.post(
  '/improve-description',
  verifyToken,
  aiController.improveDescription
);

/**
 * @swagger
 * /api/ai/generate-story-caption:
 *   post:
 *     summary: Generate an AI caption for an artisan story
 *     tags: [AI Services]
 */
router.post(
  '/generate-story-caption',
  verifyToken,
  aiController.generateStoryCaption
);

/**
 * @swagger
 * /api/ai/gift-quiz:
 *   post:
 *     summary: Generate gift recommendations based on quiz answers
 *     tags: [AI Services]
 */
router.post('/gift-quiz', aiController.giftQuiz);
/**
 * @swagger
 * /api/ai/artisan-account-assessment:
 *   post:
 *     summary: Assess a pending artisan account using Groq AI
 *     tags: [AI Services]
 *     security:
 *       - bearerAuth: []
 */
router.post(
  '/artisan-account-assessment',
  verifyToken,
  requireRole('admin'),
  aiController.assessArtisanAccount
);

/**
 * @swagger
 * /api/ai/artisan-dashboard-insights:
 *   post:
 *     summary: Generate real AI business insights for the logged-in artisan
 *     tags: [AI Services]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: false
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               language:
 *                 type: string
 *                 enum: [ar, en]
 *                 description: Preferred language for the AI insights
 *     responses:
 *       200:
 *         description: Real artisan dashboard analytics and AI insights
 */
router.post(
  '/artisan-dashboard-insights',
  verifyToken,
  aiController.artisanDashboardInsights
);

router.post('/predict-exhibition', (req, res) => res.json({ success: true, prediction: 'High success expected based on past attendance.' }));
router.post('/analyze-trust-score', (req, res) => res.json({ success: true, trustScore: 95 }));

module.exports = router;