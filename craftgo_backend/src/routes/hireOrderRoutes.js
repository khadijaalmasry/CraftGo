const express = require('express');
const router = express.Router();

const hireOrderController = require('../controllers/hireOrderController');
const { verifyToken } = require('../middlewares/authMiddleware');

router.post(
  '/requests',
  verifyToken,
  hireOrderController.createRequest
);

router.get(
  '/requests/artisan/:artisanId',
  verifyToken,
  hireOrderController.getRequestsByArtisan
);

router.get(
  '/requests/customer/:customerId',
  verifyToken,
  hireOrderController.getRequestsByCustomer
);

router.post(
  '/requests/:id/respond',
  verifyToken,
  hireOrderController.artisanRespond
);

router.patch(
  '/requests/:id/status',
  verifyToken,
  hireOrderController.updateStatus
);

module.exports = router;