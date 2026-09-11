const express = require('express');
const router = express.Router();

const productController =
  require('../controllers/productController');

const {
  verifyToken,
  optionalAuth,
} = require('../middlewares/authMiddleware');

/**
 * @swagger
 * /api/products:
 *   post:
 *     summary: Add a new product (Craftsmen only)
 *     tags: [Products]
 *     security:
 *       - bearerAuth: []
 */
router.post(
  '/',
  verifyToken,
  productController.createProduct
);

/**
 * @swagger
 * /api/products:
 *   get:
 *     summary: Get all available products with filters
 *     tags: [Products]
 *     parameters:
 *       - in: query
 *         name: category
 *       - in: query
 *         name: search
 *       - in: query
 *         name: sort
 *         description: "new|oldest|price_low|price_high|most_liked|recommended|rating"
 *       - in: query
 *         name: materials
 *         description: Comma-separated list of materials
 *       - in: query
 *         name: crafts
 *         description: Comma-separated list of craft types
 *       - in: query
 *         name: minPrice
 *       - in: query
 *         name: maxPrice
 *       - in: query
 *         name: minRating
 *       - in: query
 *         name: deliveryTime
 *       - in: query
 *         name: ecoFriendly
 */
router.get(
  '/',
  optionalAuth,
  productController.getAllProducts
);

/**
 * @swagger
 * /api/products/recommendations/{userId}:
 *   get:
 *     summary: Get AI personalized recommendations for a user (70/30 algorithm)
 *     tags: [Products]
 */
router.get(
  '/recommendations/:userId',
  optionalAuth,
  productController.getRecommendations
);

/**
 * @swagger
 * /api/products/craftsman/{craftsmanId}:
 *   get:
 *     summary: Get all products by a specific craftsman
 *     tags: [Products]
 */
router.get(
  '/craftsman/:craftsmanId',
  optionalAuth,
  productController.getProductsByCraftsman
);

/**
 * @swagger
 * /api/products/{id}:
 *   get:
 *     summary: Get a single product by ID
 *     tags: [Products]
 */
router.get(
  '/:id',
  optionalAuth,
  productController.getProductById
);

/**
 * @swagger
 * /api/products/{id}:
 *   put:
 *     summary: Update a product (owner craftsman or admin)
 *     tags: [Products]
 *     security:
 *       - bearerAuth: []
 */
router.put(
  '/:id',
  verifyToken,
  productController.updateProduct
);

/**
 * @swagger
 * /api/products/{id}:
 *   delete:
 *     summary: Delete a product (owner craftsman or admin)
 *     tags: [Products]
 *     security:
 *       - bearerAuth: []
 */
router.delete(
  '/:id',
  verifyToken,
  productController.deleteProduct
);

module.exports = router;