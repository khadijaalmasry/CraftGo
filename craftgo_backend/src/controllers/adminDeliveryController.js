const { Op } = require('sequelize');
const DeliveryOrder = require('../models/DeliveryOrder');
const DeliveryProfile = require('../models/DeliveryProfile');
const DeliveryVehicle = require('../models/DeliveryVehicle');
const DeliveryIssue = require('../models/DeliveryIssue');
const User = require('../models/User');
const Role = require('../models/Role');
const UserRole = require('../models/UserRole');
const Notification = require('../models/Notification');

// Set up User <-> Role many-to-many if not already done
User.belongsToMany(Role, { through: UserRole, foreignKey: 'userId' });
Role.belongsToMany(User, { through: UserRole, foreignKey: 'roleId' });

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/admin/delivery/stats
// Returns at-a-glance dashboard metrics, earnings summary, and recent activity
// ─────────────────────────────────────────────────────────────────────────────
exports.getDeliveryStats = async (req, res) => {
  try {
    const totalOrders = await DeliveryOrder.count();
    const activeOrders = await DeliveryOrder.count({
      where: { status: 'active' },
    });

    const startOfToday = new Date();
    startOfToday.setHours(0, 0, 0, 0);

    const startOfWeek = new Date();
    startOfWeek.setDate(startOfWeek.getDate() - startOfWeek.getDay());
    startOfWeek.setHours(0, 0, 0, 0);

    const startOfMonth = new Date();
    startOfMonth.setDate(1);
    startOfMonth.setHours(0, 0, 0, 0);

    const completedToday = await DeliveryOrder.count({
      where: {
        status: { [Op.in]: ['completed', 'delivered'] },
        updatedAt: { [Op.gte]: startOfToday },
      },
    });

    // Calculate payouts/earnings
    const todayOrders = await DeliveryOrder.findAll({
      where: {
        status: { [Op.in]: ['completed', 'delivered'] },
        updatedAt: { [Op.gte]: startOfToday },
      },
      attributes: ['earningAmount'],
    });

    const todayEarnings = todayOrders.reduce(
      (sum, o) => sum + parseFloat(o.earningAmount || 0),
      0
    );

    const weekOrders = await DeliveryOrder.findAll({
      where: {
        status: { [Op.in]: ['completed', 'delivered'] },
        updatedAt: { [Op.gte]: startOfWeek },
      },
      attributes: ['earningAmount'],
    });

    const weekEarnings = weekOrders.reduce(
      (sum, o) => sum + parseFloat(o.earningAmount || 0),
      0
    );

    const monthOrders = await DeliveryOrder.findAll({
      where: {
        status: { [Op.in]: ['completed', 'delivered'] },
        updatedAt: { [Op.gte]: startOfMonth },
      },
      attributes: ['earningAmount'],
    });

    const monthEarnings = monthOrders.reduce(
      (sum, o) => sum + parseFloat(o.earningAmount || 0),
      0
    );

    // Average delivery time from completed orders
    const completedOrdersList = await DeliveryOrder.findAll({
      where: { status: { [Op.in]: ['completed', 'delivered'] }, deliveredAt: { [Op.ne]: null } },
      attributes: ['createdAt', 'deliveredAt'],
      limit: 50,
    });

    let avgDeliveryTimeMins = 24; // Default fallback
    if (completedOrdersList.length > 0) {
      let totalMins = 0;
      completedOrdersList.forEach((o) => {
        const diffMs = new Date(o.deliveredAt) - new Date(o.createdAt);
        totalMins += Math.max(5, Math.round(diffMs / 60000));
      });
      avgDeliveryTimeMins = Math.round(totalMins / completedOrdersList.length);
    }

    // Recent activity feed (latest 10 orders)
    const recentOrders = await DeliveryOrder.findAll({
      limit: 10,
      order: [['updatedAt', 'DESC']],
      include: [
        { model: User, as: 'driver', attributes: ['id', 'name'], required: false },
        { model: User, as: 'customer', attributes: ['id', 'name'], required: false },
      ],
    });

    const recentIssues = await DeliveryIssue.findAll({
      limit: 5,
      order: [['createdAt', 'DESC']],
      include: [{ model: User, as: 'driver', attributes: ['id', 'name'], required: false }],
    });

    const activityFeed = [];

    recentIssues.forEach((iss) => {
      activityFeed.push({
        id: `issue-${iss.id}`,
        type: iss.issueType,
        text: `Issue (${iss.issueType.toUpperCase()}) reported by ${
          iss.driver?.name || 'Driver'
        }: ${iss.description}`,
        textAr: `تم الإبلاغ عن مشكلة (${iss.issueType}) بواسطة ${
          iss.driver?.name || 'المندوب'
        }: ${iss.description}`,
        time: iss.createdAt,
      });
    });

    recentOrders.forEach((ord) => {
      const driverName = ord.driver?.name || 'Driver';
      let text = `Order #${ord.orderCode} updated to ${ord.status}`;
      let textAr = `الطلب #${ord.orderCode} أصبح بحالة: ${ord.status}`;

      if (ord.status === 'active' && ord.driver) {
        text = `Driver ${driverName} accepted order #${ord.orderCode}`;
        textAr = `المندوب ${driverName} قبل الطلب #${ord.orderCode}`;
      } else if (ord.status === 'completed' || ord.status === 'delivered') {
        text = `Order #${ord.orderCode} was delivered successfully`;
        textAr = `تم توصيل الطلب #${ord.orderCode} بنجاح`;
      } else if (ord.status === 'cancelled') {
        text = `Order #${ord.orderCode} was cancelled`;
        textAr = `تم إلغاء الطلب #${ord.orderCode}`;
      }

      activityFeed.push({
        id: `ord-${ord.id}`,
        type: 'order',
        text,
        textAr,
        time: ord.updatedAt,
      });
    });

    // Sort feed by time descending
    activityFeed.sort((a, b) => new Date(b.time) - new Date(a.time));

    res.json({
      metrics: {
        totalOrders,
        activeOrders,
        completedToday,
        avgDeliveryTimeMins,
      },
      earnings: {
        todayEarnings,
        weekEarnings,
        monthEarnings,
      },
      activityFeed: activityFeed.slice(0, 10),
    });
  } catch (error) {
    console.error('getDeliveryStats error:', error);
    res.status(500).json({ error: 'Failed to fetch admin delivery stats', details: error.message });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/admin/delivery/orders
// Manage All Delivery Orders with filters (status, search, dateRange)
// ─────────────────────────────────────────────────────────────────────────────
exports.getDeliveryOrders = async (req, res) => {
  try {
    const { status, search, dateRange } = req.query;
    const where = {};

    // Map status filter — support 'available' as it's the default in the model
    if (status && status !== 'all' && status !== 'All') {
      where.status = status.toLowerCase();
    }

    if (dateRange) {
      const now = new Date();
      if (dateRange === 'today' || dateRange === 'Today') {
        const startOfToday = new Date();
        startOfToday.setHours(0, 0, 0, 0);
        where.createdAt = { [Op.gte]: startOfToday };
      } else if (dateRange === 'week' || dateRange === 'This Week') {
        const startOfWeek = new Date();
        startOfWeek.setDate(now.getDate() - now.getDay());
        startOfWeek.setHours(0, 0, 0, 0);
        where.createdAt = { [Op.gte]: startOfWeek };
      } else if (dateRange === 'month' || dateRange === 'This Month') {
        const startOfMonth = new Date();
        startOfMonth.setDate(1);
        startOfMonth.setHours(0, 0, 0, 0);
        where.createdAt = { [Op.gte]: startOfMonth };
      }
    }

    if (search) {
      const term = `%${search}%`;
      where[Op.or] = [
        { orderCode: { [Op.like]: term } },
        { pickupAddress: { [Op.like]: term } },
        { dropoffAddress: { [Op.like]: term } },
        { customerPhone: { [Op.like]: term } },
      ];
    }

    const orders = await DeliveryOrder.findAll({
      where,
      order: [['createdAt', 'DESC']],
      include: [
        { model: User, as: 'driver', attributes: ['id', 'name', 'phone', 'email'], required: false },
        { model: User, as: 'customer', attributes: ['id', 'name', 'phone', 'email'], required: false },
        { model: User, as: 'craftsman', attributes: ['id', 'name', 'phone'], required: false },
      ],
    });

    res.json(orders);
  } catch (error) {
    console.error('getDeliveryOrders error:', error);
    res.status(500).json({ error: 'Failed to fetch delivery orders', details: error.message });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/admin/delivery/orders?status=available
// Available orders for driver assignment
// ─────────────────────────────────────────────────────────────────────────────
exports.getAvailableOrdersForAssignment = async (req, res) => {
  try {
    const orders = await DeliveryOrder.findAll({
      where: { status: 'available', driverId: null },
      order: [['createdAt', 'DESC']],
      include: [
        { model: User, as: 'customer', attributes: ['id', 'name', 'phone'], required: false },
        { model: User, as: 'craftsman', attributes: ['id', 'name', 'phone'], required: false },
      ],
    });

    res.json(orders);
  } catch (error) {
    console.error('getAvailableOrdersForAssignment error:', error);
    res.status(500).json({ error: 'Failed to fetch available orders', details: error.message });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/admin/delivery/orders/:id/assign
// Assign or reassign a driver to an order
// ─────────────────────────────────────────────────────────────────────────────
exports.assignDriverToOrder = async (req, res) => {
  try {
    const { id } = req.params;
    const { driverId } = req.body;

    if (!driverId) {
      return res.status(400).json({ error: 'driverId is required' });
    }

    const order = await DeliveryOrder.findByPk(id);
    if (!order) {
      return res.status(404).json({ error: 'Delivery order not found' });
    }

    const driver = await User.findByPk(driverId);
    if (!driver) {
      return res.status(404).json({ error: 'Driver user not found' });
    }

    // Assign driver and update status to active
    order.driverId = driverId;
    order.status = 'active';
    await order.save();

    // Create notification for driver
    await Notification.create({
      userId: driverId,
      title: 'تم تعيين طلب جديد',
      titleEn: 'New Order Assigned',
      body: `تم تعيين الطلب #${order.orderCode} لك من قبل الإدارة.`,
      bodyEn: `Order #${order.orderCode} has been assigned to you by admin.`,
      type: 'order_assigned',
      relatedId: order.id,
      isRead: false,
    });

    // Return order with driver info
    const updatedOrder = await DeliveryOrder.findByPk(id, {
      include: [
        { model: User, as: 'driver', attributes: ['id', 'name', 'phone'], required: false },
        { model: User, as: 'customer', attributes: ['id', 'name', 'phone'], required: false },
      ],
    });

    res.json({
      message: 'Driver assigned successfully',
      order: updatedOrder,
    });
  } catch (error) {
    console.error('assignDriverToOrder error:', error);
    res.status(500).json({ error: 'Failed to assign driver', details: error.message });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/admin/delivery/orders/:id/cancel
// Cancel an order with admin reason
// ─────────────────────────────────────────────────────────────────────────────
exports.cancelDeliveryOrder = async (req, res) => {
  try {
    const { id } = req.params;
    const { reason } = req.body;

    const order = await DeliveryOrder.findByPk(id);
    if (!order) {
      return res.status(404).json({ error: 'Delivery order not found' });
    }

    order.status = 'cancelled';
    order.cancelledBy = 'admin';
    order.cancelReason = reason || 'Cancelled by admin';
    await order.save();

    res.json({
      message: 'Order cancelled successfully',
      order,
    });
  } catch (error) {
    console.error('cancelDeliveryOrder error:', error);
    res.status(500).json({ error: 'Failed to cancel delivery order', details: error.message });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/admin/delivery/orders/:id/status
// Direct admin status update
// ─────────────────────────────────────────────────────────────────────────────
exports.updateDeliveryOrderStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    const order = await DeliveryOrder.findByPk(id);
    if (!order) {
      return res.status(404).json({ error: 'Delivery order not found' });
    }

    order.status = status;
    if (status === 'completed' || status === 'delivered') {
      order.deliveredAt = new Date();
      const { releaseEscrowAndDistributeShares } = require('../utils/escrowHelper');
      await releaseEscrowAndDistributeShares({
        deliveryOrderId: order.id,
        orderId: order.productOrderId,
      });
    }
    await order.save();

    res.json({
      message: `Order status updated to ${status}`,
      order,
    });
  } catch (error) {
    console.error('updateDeliveryOrderStatus error:', error);
    res.status(500).json({ error: 'Failed to update delivery order status', details: error.message });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/admin/delivery/drivers
// Manage Driver Fleet — ONLY users with a delivery role and a DeliveryProfile
// ─────────────────────────────────────────────────────────────────────────────
exports.getDeliveryDrivers = async (req, res) => {
  try {
    const { status, search } = req.query;

    // Step 1: Find the delivery role
    const deliveryRole = await Role.findOne({ where: { name: 'delivery' } });
    if (!deliveryRole) {
      return res.json([]); // No delivery role configured
    }

    // Step 2: Find all userIds who have the delivery role
    const driverUserRoles = await UserRole.findAll({
      where: { roleId: deliveryRole.id },
    });
    const driverUserIds = driverUserRoles.map((ur) => ur.userId);

    if (driverUserIds.length === 0) {
      return res.json([]);
    }

    // Step 3: Build search filter on name/email/phone
    const userWhere = { id: { [Op.in]: driverUserIds } };
    if (search) {
      const term = `%${search}%`;
      userWhere[Op.and] = [
        { id: { [Op.in]: driverUserIds } },
        {
          [Op.or]: [
            { name: { [Op.like]: term } },
            { email: { [Op.like]: term } },
            { phone: { [Op.like]: term } },
          ],
        },
      ];
      delete userWhere.id;
    }

    // Step 4: Fetch delivery users with their profile and vehicle
    // required: true on DeliveryProfile ensures we only get real drivers
    const drivers = await User.findAll({
      where: userWhere,
      include: [
        {
          model: DeliveryProfile,
          as: 'deliveryProfile',
          required: true, // ONLY users who have a delivery profile
        },
        {
          model: DeliveryVehicle,
          as: 'deliveryVehicle',
          required: false, // Vehicle may not exist yet
        },
      ],
    });

    // Step 5: Format with real stats
    const formattedDrivers = await Promise.all(
      drivers.map(async (user) => {
        const profile = user.deliveryProfile;
        const vehicle = user.deliveryVehicle; // May be null - don't auto-create

        const totalCompleted = await DeliveryOrder.count({
          where: { driverId: user.id, status: { [Op.in]: ['completed', 'delivered'] } },
        });

        const activeLoadCount = await DeliveryOrder.count({
          where: { driverId: user.id, status: 'active' },
        });

        const totalAssigned = await DeliveryOrder.count({
          where: { driverId: user.id },
        });

        const completionRate =
          totalAssigned > 0
            ? Math.round((totalCompleted / totalAssigned) * 100)
            : 100;

        let driverStatus = 'active';
        if (profile.isSuspended) {
          driverStatus = 'suspended';
        } else if (profile.verificationStatus === 'pending' || !profile.isVerified) {
          driverStatus = 'pending';
        }

        // Apply status filter if provided
        if (status && status !== 'all' && status !== 'All') {
          const filterStatus = status.toLowerCase();
          if (driverStatus !== filterStatus) return null;
        }

        return {
          id: user.id,
          name: user.name,
          email: user.email,
          phone: user.phone || 'N/A',
          city: user.city || 'Ramallah',
          profileImage: user.profileImage,
          status: driverStatus,
          isSuspended: profile.isSuspended,
          verificationStatus: profile.verificationStatus || 'verified',
          isVerified: profile.isVerified,
          rating: profile.rating || 4.9,
          totalDeliveries: totalCompleted || profile.totalDeliveries || 0,
          activeLoadCount,
          completionRate,
          vehicle: vehicle
            ? {
                make: vehicle.make,
                model: vehicle.model,
                year: vehicle.year,
                color: vehicle.color,
                colorEn: vehicle.colorEn,
                licensePlate: vehicle.licensePlate,
                type: vehicle.type,
                typeEn: vehicle.typeEn,
                capacity: vehicle.capacity,
              }
            : null, // Return null if no vehicle — don't fake it
          documents: {
            idCardUrl: profile.idCardUrl || null,
            facePhotoUrl: profile.facePhotoUrl || user.profileImage || null,
            permitUrl: profile.permitUrl || null,
          },
        };
      })
    );

    // Filter out nulls (from status filter)
    const filtered = formattedDrivers.filter(Boolean);
    res.json(filtered);
  } catch (error) {
    console.error('getDeliveryDrivers error:', error);
    res.status(500).json({ error: 'Failed to fetch delivery drivers', details: error.message });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/admin/delivery/drivers/:id
// Full driver profile with order history
// ─────────────────────────────────────────────────────────────────────────────
exports.getDriverDetails = async (req, res) => {
  try {
    const { id } = req.params;

    const user = await User.findByPk(id, {
      include: [
        { model: DeliveryProfile, as: 'deliveryProfile', required: false },
        { model: DeliveryVehicle, as: 'deliveryVehicle', required: false },
      ],
    });

    if (!user) {
      return res.status(404).json({ error: 'Driver not found' });
    }

    const recentOrders = await DeliveryOrder.findAll({
      where: { driverId: id },
      order: [['createdAt', 'DESC']],
      limit: 20,
      include: [
        { model: User, as: 'customer', attributes: ['id', 'name', 'phone'], required: false },
        { model: User, as: 'craftsman', attributes: ['id', 'name', 'phone'], required: false },
      ],
    });

    const totalCompleted = await DeliveryOrder.count({
      where: { driverId: id, status: { [Op.in]: ['completed', 'delivered'] } },
    });

    const totalAssigned = await DeliveryOrder.count({ where: { driverId: id } });
    const completionRate = totalAssigned > 0
      ? Math.round((totalCompleted / totalAssigned) * 100)
      : 100;

    res.json({
      user,
      recentOrders,
      stats: {
        totalCompleted,
        totalAssigned,
        completionRate,
      },
    });
  } catch (error) {
    console.error('getDriverDetails error:', error);
    res.status(500).json({ error: 'Failed to fetch driver details', details: error.message });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/admin/delivery/drivers/:id/verify
// Update driver verification status
// ─────────────────────────────────────────────────────────────────────────────
exports.verifyDriver = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body; // 'verified' or 'rejected'

    let profile = await DeliveryProfile.findOne({ where: { driverId: id } });
    if (!profile) {
      return res.status(404).json({ error: 'Driver profile not found' });
    }

    profile.verificationStatus = status || 'verified';
    profile.isVerified = status === 'verified';
    await profile.save();

    res.json({
      message: `Driver verification status updated to ${profile.verificationStatus}`,
      profile,
    });
  } catch (error) {
    console.error('verifyDriver error:', error);
    res.status(500).json({ error: 'Failed to verify driver', details: error.message });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/admin/delivery/drivers/:id/suspend
// Suspend or Reactivate driver
// ─────────────────────────────────────────────────────────────────────────────
exports.suspendDriver = async (req, res) => {
  try {
    const { id } = req.params;
    const { isSuspended } = req.body;

    let profile = await DeliveryProfile.findOne({ where: { driverId: id } });
    if (!profile) {
      return res.status(404).json({ error: 'Driver profile not found' });
    }

    profile.isSuspended = isSuspended !== undefined ? isSuspended : !profile.isSuspended;
    await profile.save();

    res.json({
      message: `Driver is ${profile.isSuspended ? 'suspended' : 'reactivated'}`,
      isSuspended: profile.isSuspended,
    });
  } catch (error) {
    console.error('suspendDriver error:', error);
    res.status(500).json({ error: 'Failed to toggle driver suspension', details: error.message });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/admin/delivery/issues
// Get all reported issues & emergency SOS alerts with metrics
// ─────────────────────────────────────────────────────────────────────────────
exports.getDeliveryIssues = async (req, res) => {
  try {
    const { type, status } = req.query;
    const where = {};

    if (type && type !== 'all' && type !== 'All') {
      where.issueType = type.toLowerCase();
    }

    if (status && status !== 'all' && status !== 'All') {
      where.status = status.toLowerCase();
    }

    const issues = await DeliveryIssue.findAll({
      where,
      order: [['createdAt', 'DESC']],
      include: [
        { model: User, as: 'driver', attributes: ['id', 'name', 'phone', 'email'], required: false },
        {
          model: DeliveryOrder,
          as: 'order',
          attributes: ['id', 'orderCode', 'status', 'dropoffAddress', 'pickupAddress'],
          required: false,
        },
      ],
    });

    const fraudCount = await DeliveryIssue.count({
      where: { issueType: 'fraud', status: { [Op.notIn]: ['resolved', 'dismissed'] } },
    });
    const sosCount = await DeliveryIssue.count({
      where: { issueType: 'sos', status: { [Op.notIn]: ['resolved', 'dismissed'] } },
    });
    const complaintCount = await DeliveryIssue.count({
      where: { issueType: 'complaint', status: { [Op.notIn]: ['resolved', 'dismissed'] } },
    });
    const undeliveredCount = await DeliveryIssue.count({
      where: { issueType: 'undelivered', status: { [Op.notIn]: ['resolved', 'dismissed'] } },
    });

    res.json({
      alertCounts: {
        fraudCount,
        sosCount,
        complaintCount,
        undeliveredCount,
      },
      issues,
    });
  } catch (error) {
    console.error('getDeliveryIssues error:', error);
    res.status(500).json({ error: 'Failed to fetch delivery issues', details: error.message });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/admin/delivery/issues/:id/resolve
// Mark issue as resolved with admin notes
// ─────────────────────────────────────────────────────────────────────────────
exports.resolveIssue = async (req, res) => {
  try {
    const { id } = req.params;
    const { notes } = req.body;

    const issue = await DeliveryIssue.findByPk(id);
    if (!issue) {
      return res.status(404).json({ error: 'Delivery issue not found' });
    }

    issue.status = 'resolved';
    issue.notes = notes || 'Resolved by admin';
    issue.resolvedAt = new Date();
    await issue.save();

    res.json({
      message: 'Issue resolved successfully',
      issue,
    });
  } catch (error) {
    console.error('resolveIssue error:', error);
    res.status(500).json({ error: 'Failed to resolve issue', details: error.message });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/admin/delivery/issues/:id/dismiss
// Dismiss issue (false alarm)
// ─────────────────────────────────────────────────────────────────────────────
exports.dismissIssue = async (req, res) => {
  try {
    const { id } = req.params;

    const issue = await DeliveryIssue.findByPk(id);
    if (!issue) {
      return res.status(404).json({ error: 'Delivery issue not found' });
    }

    issue.status = 'dismissed';
    await issue.save();

    res.json({
      message: 'Issue dismissed',
      issue,
    });
  } catch (error) {
    console.error('dismissIssue error:', error);
    res.status(500).json({ error: 'Failed to dismiss issue', details: error.message });
  }
};
