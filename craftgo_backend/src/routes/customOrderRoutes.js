const express = require('express');
const router = express.Router();

const customOrderController =
  require('../controllers/customOrderController');

const {
  verifyToken
} = require('../middlewares/authMiddleware');

// Templates routes
router.post(
  '/templates',
  verifyToken,
  customOrderController.createTemplate
);

router.put(
  '/templates/:id',
  verifyToken,
  customOrderController.updateTemplate
);

router.delete(
  '/templates/:id',
  verifyToken,
  customOrderController.deleteTemplate
);

router.get(
  '/templates/artisan/:artisanId',
  customOrderController.getTemplatesByArtisan
);

router.get(
  '/templates/:id',
  customOrderController.getTemplateById
);

// Requests routes
router.post(
  '/requests',
  verifyToken,
  customOrderController.submitRequest
);

router.get(
  '/requests/customer/:customerId',
  verifyToken,
  customOrderController.getRequestsByCustomer
);

router.get(
  '/requests/artisan/:artisanId',
  verifyToken,
  customOrderController.getRequestsByArtisan
);

router.post(
  '/requests/:id/respond',
  verifyToken,
  customOrderController.artisanRespond
);

router.patch(
  '/requests/:id/status',
  verifyToken,
  customOrderController.updateRequestStatus
);

// NEW — progress
router.patch(
  '/requests/:id/progress',
  verifyToken,
  customOrderController.updateRequestProgress
);


router.post(
  '/requests/:id/sign',
  verifyToken,
  customOrderController.signContract
);

router.delete(
  '/requests/:id',
  verifyToken,
  customOrderController.deleteRequest
);

router.patch('/requests/:id/delivery',
  verifyToken,
  customOrderController.updateDeliveryInfo
);

// GET a single custom order request by ID
router.get('/requests/:id', verifyToken, customOrderController.getRequestById);

module.exports = router;