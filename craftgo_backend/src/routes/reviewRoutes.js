const express = require('express');
const router = express.Router();

const reviewController =
  require('../controllers/reviewController');

const {
  verifyToken
} = require('../middlewares/authMiddleware');


// Customer rates artisan after a completed order
router.post(
  '/',
  verifyToken,
  reviewController.createReview
);


// Check whether the logged-in customer
// already reviewed the artisan for a specific order
router.get(
  '/order/:orderId',
  verifyToken,
  reviewController.getOrderReview
);


// Artisan rates customer after a completed order
router.post(
  '/customer',
  verifyToken,
  reviewController.createCustomerReview
);


// Check whether the logged-in artisan
// already reviewed the customer for a specific order
router.get(
  '/customer/order/:orderId',
  verifyToken,
  reviewController.getCustomerReviewForOrder
);


module.exports = router;