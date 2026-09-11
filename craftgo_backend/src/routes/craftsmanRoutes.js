const express = require('express');
const router = express.Router();
const craftsmanController = require('../controllers/craftsmanController');
const {
    verifyToken
} = require('../middlewares/authMiddleware');
router.get('/test', (req, res) => {
    res.json({
        message: 'Craftsman routes are working!'
    });
});

// GET All craftsmen (Public or authenticated)
router.get('/', craftsmanController.getAllCraftsmen);
router.get('/all', craftsmanController.getAllCraftsmen);

// All other routes require authentication
router.use(verifyToken);

// Profile
router.get('/profile/:id', craftsmanController.getProfile);
router.put('/profile/:id', craftsmanController.updateProfile);

// Portfolio
router.get('/portfolio/:id', craftsmanController.getPortfolio);
router.post('/portfolio', craftsmanController.addPortfolioItem);
console.log('POST /portfolio route registered');
router.delete('/portfolio/:itemId', craftsmanController.deletePortfolioItem);

// Reviews
router.get('/reviews/:id', craftsmanController.getReviews);

// Favorites
router.get('/favorites', (req, res) => res.json([]));
router.post('/favorite', (req, res) => res.json({ success: true }));

module.exports = router;