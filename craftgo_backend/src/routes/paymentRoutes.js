const express = require('express');

const router = express.Router();

const paymentController =
  require('../controllers/paymentController');

const productPaymentController =
  require('../controllers/productPaymentController');

const {
  verifyToken,
  requireRole
} = require('../middlewares/authMiddleware');

// ─────────────────────────────────────────────────────────────
// Hire / On-Site Payments
// ─────────────────────────────────────────────────────────────

// إنشاء Payment Intent لطلب Hire
router.post(
  '/hire/:hireRequestId/intent',
  verifyToken,
  paymentController.createPaymentIntent
);

// إنشاء Stripe Checkout Session لطلب Hire
router.post(
  '/hire/:hireRequestId/checkout',
  verifyToken,
  paymentController.createCheckoutSession
);

// تأكيد دفع طلب Hire
router.post(
  '/hire/:hireRequestId/confirm',
  verifyToken,
  paymentController.confirmPayment
);

// جلب معلومات دفع طلب Hire
router.get(
  '/hire/:hireRequestId',
  verifyToken,
  paymentController.getPaymentForHire
);

// إنشاء Payment Intent لحجز كشك معرض
router.post(
  '/exhibitions/:exhibitionId/intent',
  verifyToken,
  paymentController.createExhibitionBoothIntent
);

// Create and check a hosted Stripe Checkout Session for a booth
router.post(
  '/exhibitions/:exhibitionId/checkout',
  verifyToken,
  paymentController.createExhibitionBoothCheckout
);
router.get(
  '/exhibitions/:exhibitionId/checkout/:sessionId',
  verifyToken,
  paymentController.getExhibitionBoothCheckout
);

// جلب أرباح منظم المعارض
router.get(
  '/exhibitions/owner/earnings',
  verifyToken,
  paymentController.getExhibitionOwnerEarnings
);

// جلب أرباح الحرفي
router.get(
  '/artisan/:artisanId/earnings',
  verifyToken,
  paymentController.getArtisanEarnings
);

// Stripe Express Connected Account payout link for all roles
router.post(
  '/payout/onboard',
  verifyToken,
  paymentController.createPayoutSession
);

// ── Delivery Payments (Escrow) ─────────────────────────────────────────
// Create PaymentIntent for delivery order
router.post(
  '/delivery/:deliveryOrderId/intent',
  verifyToken,
  paymentController.createDeliveryIntent,
);

// Confirm delivery payment (client -> server check)
router.post(
  '/delivery/:deliveryOrderId/confirm',
  verifyToken,
  paymentController.confirmDeliveryPayment,
);

// Get delivery payment
router.get(
  '/delivery/:deliveryOrderId',
  verifyToken,
  paymentController.getPaymentForDelivery,
);

// Admin release delivery escrow
router.post(
  '/admin/delivery/:deliveryOrderId/release',
  verifyToken,
  requireRole('admin'),
  paymentController.releaseDeliveryEscrow,
);

// ─────────────────────────────────────────────────────────────
// Admin Payment Operations
// ─────────────────────────────────────────────────────────────

// جلب جميع معاملات Hire والمنتجات للأدمن
router.get(
  '/admin/transactions',
  verifyToken,
  requireRole('admin'),
  paymentController.getAdminTransactions
);

// تحرير مبلغ Hire من Escrow بواسطة الأدمن
router.post(
  '/admin/hire/:hireRequestId/release',
  verifyToken,
  requireRole('admin'),
  paymentController.releaseEscrow
);

// ─────────────────────────────────────────────────────────────
// Ready-Made Product Payments
// ─────────────────────────────────────────────────────────────

// إنشاء Stripe Checkout لشراء منتج
router.post(
  '/products/checkout',
  verifyToken,
  productPaymentController.createCheckout
);

// فحص حالة الدفع بعد الرجوع من Stripe
router.get(
  '/products/status/:sessionId',
  verifyToken,
  productPaymentController.getStatus
);

// صفحة نجاح دفع المنتج
router.get(
  '/products/success',
  productPaymentController.checkoutSuccess
);

// ─────────────────────────────────────────────────────────────
// Stripe Hire Checkout Result Pages
// ─────────────────────────────────────────────────────────────

// صفحة نجاح دفع Hire
router.get(
  '/checkout/success',
  paymentController.checkoutSuccess
);

// صفحة إلغاء دفع Hire
router.get(
  '/checkout/cancel',
  paymentController.checkoutCancelled
);


// Custom order payments
router.post(
  '/custom/:requestId/intent',
  verifyToken,
  paymentController.createCustomOrderIntent
);
router.post(
  '/custom/:requestId/checkout',
  verifyToken,
  paymentController.createCustomOrderCheckoutSession
);
router.post(
  '/custom/:requestId/confirm',
  verifyToken,
  paymentController.confirmCustomOrderPayment
);

module.exports = router;