const express = require('express');
const router = express.Router();

const notificationController = require('../controllers/notificationController');
const { verifyToken } = require('../middlewares/authMiddleware');



router.get(
  '/',
  verifyToken,
  notificationController.getMyNotifications
);

router.patch(
  '/read-all',
  verifyToken,
  notificationController.markAllAsRead
);

router.patch(
  '/:id/read',
  verifyToken,
  notificationController.markAsRead
);

router.delete(
  '/',
  verifyToken,
  notificationController.deleteAllNotifications
);

router.delete(
  '/:id',
  verifyToken,
  notificationController.deleteNotification
);
module.exports = router;