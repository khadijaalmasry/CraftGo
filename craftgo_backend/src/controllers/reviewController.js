const Review = require('../models/Review');
const Order = require('../models/Order');
const CustomOrderRequest = require('../models/CustomOrderRequest');
const HireRequest = require('../models/HireRequest');

const cleanComment = (value) => {
  if (typeof value !== 'string') return null;
  const cleaned = value.trim();
  return cleaned.length > 0 ? cleaned : null;
};

// POST /api/reviews
exports.createReview = async (req, res) => {
  try {
    const customerId = req.user?.id;
    const {
      orderId,
      rating,
      commentAr,
      commentEn,
    } = req.body;

    if (!customerId) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized',
      });
    }

    if (!orderId) {
      return res.status(400).json({
        success: false,
        error: 'orderId is required',
      });
    }

    const numericRating = Number(rating);

    if (
      !Number.isInteger(numericRating) ||
      numericRating < 1 ||
      numericRating > 5
    ) {
      return res.status(400).json({
        success: false,
        error: 'Rating must be an integer between 1 and 5',
      });
    }

    const reviewComments = {
      commentAr: cleanComment(commentAr),
      commentEn: cleanComment(commentEn),
    };

    // =====================================================
    // 1. Ready-Made Order
    // =====================================================

    const order = await Order.findByPk(orderId);

    if (order) {
      if (String(order.customerId) !== String(customerId)) {
        return res.status(403).json({
          success: false,
          error: 'You cannot review this order',
        });
      }

      if (order.status !== 'completed') {
        return res.status(400).json({
          success: false,
          error: 'The order must be completed before reviewing',
        });
      }

      const existingReview = await Review.findOne({
        where: {
          orderId: order.id,
          customerId,
          direction: 'customer_to_artisan',
        },
      });

      if (existingReview) {
        return res.status(409).json({
          success: false,
          error: 'You have already reviewed this order',
          review: existingReview,
        });
      }

      const review = await Review.create({
        artisanId: order.craftsmanId,
        customerId,
        direction: 'customer_to_artisan',
        orderId: order.id,
        customOrderRequestId: null,
        hireRequestId: null,
        rating: numericRating,
        ...reviewComments,
      });

      return res.status(201).json({
        success: true,
        message: 'Review submitted successfully',
        orderType: 'ready-made',
        review,
      });
    }

    // =====================================================
    // 2. Custom Order
    // =====================================================

    const customOrder = await CustomOrderRequest.findByPk(orderId);

    if (customOrder) {
      if (String(customOrder.customerId) !== String(customerId)) {
        return res.status(403).json({
          success: false,
          error: 'You cannot review this custom order',
        });
      }

      if (customOrder.status !== 'completed') {
        return res.status(400).json({
          success: false,
          error: 'The custom order must be completed before reviewing',
        });
      }

      if (!customOrder.artisanId) {
        return res.status(400).json({
          success: false,
          error: 'This custom order does not have an artisan',
        });
      }

      const existingReview = await Review.findOne({
        where: {
          customOrderRequestId: customOrder.id,
          customerId,
          direction: 'customer_to_artisan',
        },
      });

      if (existingReview) {
        return res.status(409).json({
          success: false,
          error: 'You have already reviewed this custom order',
          review: existingReview,
        });
      }

      const review = await Review.create({
        artisanId: customOrder.artisanId,
        customerId,
        direction: 'customer_to_artisan',
        orderId: null,
        customOrderRequestId: customOrder.id,
        hireRequestId: null,
        rating: numericRating,
        ...reviewComments,
      });

      return res.status(201).json({
        success: true,
        message: 'Custom order review submitted successfully',
        orderType: 'custom',
        review,
      });
    }

    // =====================================================
    // 3. Hire / On-Site Order
    // =====================================================

    const hireRequest = await HireRequest.findByPk(orderId);

    if (!hireRequest) {
      return res.status(404).json({
        success: false,
        error: 'Order not found',
      });
    }

    if (String(hireRequest.customerId) !== String(customerId)) {
      return res.status(403).json({
        success: false,
        error: 'You cannot review this hire order',
      });
    }

    if (hireRequest.status !== 'completed') {
      return res.status(400).json({
        success: false,
        error: 'The hire order must be completed before reviewing',
      });
    }

    const existingHireReview = await Review.findOne({
      where: {
        hireRequestId: hireRequest.id,
        customerId,
        direction: 'customer_to_artisan',
      },
    });

    if (existingHireReview) {
      return res.status(409).json({
        success: false,
        error: 'You have already reviewed this hire order',
        review: existingHireReview,
      });
    }

    const review = await Review.create({
      artisanId: hireRequest.artisanId,
      customerId,
      direction: 'customer_to_artisan',
      orderId: null,
      customOrderRequestId: null,
      hireRequestId: hireRequest.id,
      rating: numericRating,
      ...reviewComments,
    });

    return res.status(201).json({
      success: true,
      message: 'Hire order review submitted successfully',
      orderType: 'hire',
      review,
    });
  } catch (error) {
    console.error('[createReview] ERROR:', error);

    return res.status(500).json({
      success: false,
      error: 'Failed to submit review',
      details: error.message,
    });
  }
};

// GET /api/reviews/order/:orderId
exports.getOrderReview = async (req, res) => {
  try {
    const customerId = req.user?.id;
    const { orderId } = req.params;

    if (!customerId) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized',
      });
    }

    let review = await Review.findOne({
      where: {
        orderId,
        customerId,
        direction: 'customer_to_artisan',
      },
    });

    if (review) {
      return res.json({
        success: true,
        reviewed: true,
        orderType: 'ready-made',
        review,
      });
    }

    review = await Review.findOne({
      where: {
        customOrderRequestId: orderId,
        customerId,
        direction: 'customer_to_artisan',
      },
    });

    if (review) {
      return res.json({
        success: true,
        reviewed: true,
        orderType: 'custom',
        review,
      });
    }

    review = await Review.findOne({
      where: {
        hireRequestId: orderId,
        customerId,
        direction: 'customer_to_artisan',
      },
    });

    if (review) {
      return res.json({
        success: true,
        reviewed: true,
        orderType: 'hire',
        review,
      });
    }

    return res.json({
      success: true,
      reviewed: false,
      review: null,
    });
  } catch (error) {
    console.error('[getOrderReview] ERROR:', error);

    return res.status(500).json({
      success: false,
      error: 'Failed to fetch review',
      details: error.message,
    });
  }
};

// POST /api/reviews/customer
// Artisan rates the customer after a completed order.
exports.createCustomerReview = async (req, res) => {
  try {
    const artisanId = req.user?.id;
    const {
      orderId,
      rating,
      commentAr,
      commentEn,
    } = req.body;

    if (!artisanId) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized',
      });
    }

    if (!orderId) {
      return res.status(400).json({
        success: false,
        error: 'orderId is required',
      });
    }

    const numericRating = Number(rating);

    if (
      !Number.isInteger(numericRating) ||
      numericRating < 1 ||
      numericRating > 5
    ) {
      return res.status(400).json({
        success: false,
        error: 'Rating must be an integer between 1 and 5',
      });
    }

    const reviewComments = {
      commentAr: cleanComment(commentAr),
      commentEn: cleanComment(commentEn),
    };

    // =====================================================
    // 1. Ready-Made Order
    // =====================================================
    const order = await Order.findByPk(orderId);

    if (order) {
      if (String(order.craftsmanId) !== String(artisanId)) {
        return res.status(403).json({
          success: false,
          error: 'You cannot review this customer',
        });
      }

      if (
        order.status !== 'completed' &&
        order.status !== 'delivered'
      ) {
        return res.status(400).json({
          success: false,
          error: 'The order must be completed before reviewing',
        });
      }

      const existing = await Review.findOne({
        where: {
          orderId: order.id,
          artisanId,
          direction: 'artisan_to_customer',
        },
      });

      if (existing) {
        return res.status(409).json({
          success: false,
          error: 'You have already reviewed this customer for this order',
          review: existing,
        });
      }

      const review = await Review.create({
        artisanId,
        customerId: order.customerId,
        direction: 'artisan_to_customer',
        orderId: order.id,
        customOrderRequestId: null,
        hireRequestId: null,
        rating: numericRating,
        ...reviewComments,
      });

      return res.status(201).json({
        success: true,
        message: 'Customer review submitted successfully',
        orderType: 'ready-made',
        review,
      });
    }

    // =====================================================
    // 2. Custom Order
    // =====================================================
    const customOrder = await CustomOrderRequest.findByPk(orderId);

    if (customOrder) {
      if (String(customOrder.artisanId) !== String(artisanId)) {
        return res.status(403).json({
          success: false,
          error: 'You cannot review this customer',
        });
      }

      if (customOrder.status !== 'completed') {
        return res.status(400).json({
          success: false,
          error: 'The custom order must be completed before reviewing',
        });
      }

      const existing = await Review.findOne({
        where: {
          customOrderRequestId: customOrder.id,
          artisanId,
          direction: 'artisan_to_customer',
        },
      });

      if (existing) {
        return res.status(409).json({
          success: false,
          error:
            'You have already reviewed this customer for this custom order',
          review: existing,
        });
      }

      const review = await Review.create({
        artisanId,
        customerId: customOrder.customerId,
        direction: 'artisan_to_customer',
        orderId: null,
        customOrderRequestId: customOrder.id,
        hireRequestId: null,
        rating: numericRating,
        ...reviewComments,
      });

      return res.status(201).json({
        success: true,
        message: 'Customer review submitted successfully',
        orderType: 'custom',
        review,
      });
    }

    // =====================================================
    // 3. Hire / On-Site Order
    // =====================================================
    const hireRequest = await HireRequest.findByPk(orderId);

    if (!hireRequest) {
      return res.status(404).json({
        success: false,
        error: 'Order not found',
      });
    }

    if (String(hireRequest.artisanId) !== String(artisanId)) {
      return res.status(403).json({
        success: false,
        error: 'You cannot review this customer',
      });
    }

    if (hireRequest.status !== 'completed') {
      return res.status(400).json({
        success: false,
        error: 'The hire order must be completed before reviewing',
      });
    }

    const existing = await Review.findOne({
      where: {
        hireRequestId: hireRequest.id,
        artisanId,
        direction: 'artisan_to_customer',
      },
    });

    if (existing) {
      return res.status(409).json({
        success: false,
        error:
          'You have already reviewed this customer for this hire order',
        review: existing,
      });
    }

    const review = await Review.create({
      artisanId,
      customerId: hireRequest.customerId,
      direction: 'artisan_to_customer',
      orderId: null,
      customOrderRequestId: null,
      hireRequestId: hireRequest.id,
      rating: numericRating,
      ...reviewComments,
    });

    return res.status(201).json({
      success: true,
      message: 'Customer review submitted successfully',
      orderType: 'hire',
      review,
    });
  } catch (error) {
    console.error('[createCustomerReview] ERROR:', error);

    return res.status(500).json({
      success: false,
      error: 'Failed to submit customer review',
      details: error.message,
    });
  }
};

// GET /api/reviews/customer/order/:orderId
// Check whether the logged-in artisan already rated the customer.
exports.getCustomerReviewForOrder = async (req, res) => {
  try {
    const artisanId = req.user?.id;
    const { orderId } = req.params;

    if (!artisanId) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized',
      });
    }

    let review = await Review.findOne({
      where: {
        orderId,
        artisanId,
        direction: 'artisan_to_customer',
      },
    });

    if (review) {
      return res.json({
        success: true,
        reviewed: true,
        orderType: 'ready-made',
        review,
      });
    }

    review = await Review.findOne({
      where: {
        customOrderRequestId: orderId,
        artisanId,
        direction: 'artisan_to_customer',
      },
    });

    if (review) {
      return res.json({
        success: true,
        reviewed: true,
        orderType: 'custom',
        review,
      });
    }

    review = await Review.findOne({
      where: {
        hireRequestId: orderId,
        artisanId,
        direction: 'artisan_to_customer',
      },
    });

    if (review) {
      return res.json({
        success: true,
        reviewed: true,
        orderType: 'hire',
        review,
      });
    }

    return res.json({
      success: true,
      reviewed: false,
      review: null,
    });
  } catch (error) {
    console.error('[getCustomerReviewForOrder] ERROR:', error);

    return res.status(500).json({
      success: false,
      error: 'Failed to fetch customer review',
      details: error.message,
    });
  }
};