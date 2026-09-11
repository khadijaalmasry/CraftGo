
const Notification = require('../models/Notification');

// GET /api/notifications
exports.getMyNotifications = async (req, res) => {
  try {
    const userId = req.user.id;

    const notifications = await Notification.findAll({
      where: { userId },
      order: [['createdAt', 'DESC']],
    });

    return res.json(notifications);
  } catch (error) {
    console.error('Failed to fetch notifications:', error);

    return res.status(500).json({
      error: 'Failed to fetch notifications',
    });
  }
};

// PATCH /api/notifications/:id/read
exports.markAsRead = async (req, res) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;

    const notification = await Notification.findOne({
      where: {
        id,
        userId,
      },
    });

    if (!notification) {
      return res.status(404).json({
        error: 'Notification not found',
      });
    }

    notification.isRead = true;
    await notification.save();

    return res.json({
      success: true,
      notification,
    });
  } catch (error) {
    console.error('Failed to mark notification as read:', error);

    return res.status(500).json({
      error: 'Failed to mark notification as read',
    });
  }
};

// PATCH /api/notifications/read-all
exports.markAllAsRead = async (req, res) => {
  try {
    const userId = req.user.id;

    const [updatedCount] = await Notification.update(
      { isRead: true },
      {
        where: {
          userId,
          isRead: false,
        },
      }
    );

    return res.json({
      success: true,
      updatedCount,
    });
  } catch (error) {
    console.error('Failed to mark all notifications as read:', error);

    return res.status(500).json({
      error: 'Failed to mark all notifications as read',
    });
  }
};

// DELETE /api/notifications/:id
exports.deleteNotification = async (req, res) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;

    const deletedCount = await Notification.destroy({
      where: {
        id,
        userId,
      },
    });

    if (deletedCount === 0) {
      return res.status(404).json({
        error: 'Notification not found',
      });
    }

    return res.json({
      success: true,
      message: 'Notification deleted',
    });
  } catch (error) {
    console.error('Failed to delete notification:', error);

    return res.status(500).json({
      error: 'Failed to delete notification',
    });
  }
};

// DELETE /api/notifications
exports.deleteAllNotifications = async (req, res) => {
  try {
    const userId = req.user.id;

    const deletedCount = await Notification.destroy({
      where: { userId },
    });

    return res.json({
      success: true,
      deletedCount,
    });
  } catch (error) {
    console.error('Failed to delete all notifications:', error);

    return res.status(500).json({
      error: 'Failed to delete all notifications',
    });
  }
};