const {
  Op
} = require('sequelize');
const DeliveryProfile = require('../models/DeliveryProfile');
const DeliveryVehicle = require('../models/DeliveryVehicle');
const DeliveryOrder = require('../models/DeliveryOrder');
const DeliveryPayment = require('../models/DeliveryPayment');
const Notification = require('../models/Notification');
const User = require('../models/User');
const Product = require('../models/Product');
const Payout = require('../models/Payout');


// ── Helper to format DeliveryOrder payload for driver apps ─────────────────
async function formatDeliveryOrder(dOrder) {
  if (!dOrder) return null;
  const plain = dOrder.get ? dOrder.get({ plain: true }) : { ...dOrder };

  let pIds = [];
  if (plain.relatedOrderIds) {
    try {
      const parsed = JSON.parse(plain.relatedOrderIds);
      if (Array.isArray(parsed)) pIds = parsed.map(String);
    } catch (_) {}
  }
  if (pIds.length === 0 && plain.productOrderId) {
    pIds = [String(plain.productOrderId)];
  }

  let cIds = [];
  if (plain.relatedCustomOrderIds) {
    try {
      const parsed = JSON.parse(plain.relatedCustomOrderIds);
      if (Array.isArray(parsed)) cIds = parsed.map(String);
    } catch (_) {}
  }
  if (cIds.length === 0 && plain.customOrderId) {
    cIds = [String(plain.customOrderId)];
  }

  const totalItemsCount = pIds.length + cIds.length;
  const isBatch = totalItemsCount > 1;

  let productName = plain.productName || '';
  let productNameEn = plain.productNameEn || '';

  if (isBatch) {
    if (plain.product && (plain.product.titleAr || plain.product.titleEn)) {
      const firstAr = plain.product.titleAr || plain.product.titleEn;
      const firstEn = plain.product.titleEn || plain.product.titleAr;
      const remaining = totalItemsCount - 1;
      productName = remaining > 0 ? `${firstAr} (+${remaining} طلبات أخرى)` : firstAr;
      productNameEn = remaining > 0 ? `${firstEn} (+${remaining} other items)` : firstEn;
    } else {
      productName = `شحنة مجمعة (${totalItemsCount} طلبات)`;
      productNameEn = `Batch Delivery (${totalItemsCount} items)`;
    }
  } else if (!productName && (plain.orderType === 'custom_made' || cIds.length > 0)) {
    productName = plain.customSpecifications || 'طلب خاص (تفصيل)';
    productNameEn = plain.customSpecifications || 'Custom Made Order';
  } else if (!productName && plain.product) {
    productName = plain.product.titleAr || plain.product.titleEn || 'منتج جاهز';
    productNameEn = plain.product.titleEn || plain.product.titleAr || 'Ready-made Product';
  } else if (!productName) {
    productName = 'طلب شحنة كرافت جو';
    productNameEn = 'CraftGo Shipment';
  }

  let customerPhone = plain.customerPhone || (plain.customer ? plain.customer.phone : '') || '';
  let pickupPhone = plain.pickupPhone || (plain.craftsman ? plain.craftsman.phone : '') || '';
  let customerName = (plain.customer ? plain.customer.name : '') || plain.customerName || '';
  let craftsmanName = (plain.craftsman ? plain.craftsman.name : '') || plain.craftsmanName || '';

  // Deep Fallback: If customer phone/name missing, check User table & associated orders
  if (!customerPhone || !customerName) {
    if (plain.customerId) {
      try {
        const u = await User.findByPk(plain.customerId);
        if (u) {
          if (!customerPhone && u.phone) customerPhone = u.phone;
          if (!customerName && u.name) customerName = u.name;
        }
      } catch (_) {}
    }
    if (!customerPhone && pIds.length > 0) {
      try {
        const ProductOrder = require('../models/Order');
        const pOrd = await ProductOrder.findByPk(pIds[0]);
        if (pOrd && pOrd.customerPhone) customerPhone = pOrd.customerPhone;
      } catch (_) {}
    }
    if (!customerPhone && cIds.length > 0) {
      try {
        const CustomOrderRequest = require('../models/CustomOrderRequest');
        const cReq = await CustomOrderRequest.findByPk(cIds[0]);
        if (cReq && cReq.customerPhone) customerPhone = cReq.customerPhone;
      } catch (_) {}
    }
  }

  // Deep Fallback: If craftsman phone/name missing, check User table
  if (!pickupPhone || !craftsmanName) {
    if (plain.craftsmanId) {
      try {
        const cr = await User.findByPk(plain.craftsmanId);
        if (cr) {
          if (!pickupPhone && cr.phone) pickupPhone = cr.phone;
          if (!craftsmanName && cr.name) craftsmanName = cr.name;
        }
      } catch (_) {}
    }
  }

  return {
    ...plain,
    isBatch,
    totalItemsCount: totalItemsCount || 1,
    productName,
    productNameEn,
    customerPhone: customerPhone || '',
    pickupPhone: pickupPhone || '',
    customerName: customerName || 'عميل كرافت جو',
    craftsmanName: craftsmanName || 'حرفي كرافت جو',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/delivery/dashboard/:driverId
// ─────────────────────────────────────────────────────────────────────────────
exports.getDashboard = async (req, res) => {
  try {
    const {
      driverId
    } = req.params;

    let profile = await DeliveryProfile.findOne({
      where: {
        driverId
      }
    });
    if (!profile) {
      profile = await DeliveryProfile.create({
        driverId
      });
    }

    let vehicle = await DeliveryVehicle.findOne({
      where: {
        driverId
      }
    });
    if (!vehicle) {
      vehicle = await DeliveryVehicle.create({
        driverId
      });
    }

    const totalCompleted = await DeliveryOrder.count({
      where: {
        driverId,
        status: {
          [Op.in]: ['completed', 'delivered']
        }
      },
    });

    const activeOrder = await DeliveryOrder.findOne({
      where: {
        driverId,
        status: {
          [Op.in]: ['active', 'in_progress']
        }
      },
      order: [
        ['updatedAt', 'DESC']
      ],
      include: [{
          model: User,
          as: 'customer',
          attributes: ['id', 'name', 'phone', 'city'],
          required: false
        },
        {
          model: User,
          as: 'craftsman',
          attributes: ['id', 'name', 'phone', 'city'],
          required: false
        },
        {
          model: Product,
          as: 'product',
          attributes: ['id', 'titleAr', 'titleEn', 'imageUrl', 'price'],
          required: false
        },
      ],
    });

    const formattedActiveOrder = activeOrder ? await formatDeliveryOrder(activeOrder) : null;

    res.json({
      isOnline: profile.isOnline,
      isSuspended: profile.isSuspended || false,
      rating: profile.rating,
      stats: {
        totalCompleted: totalCompleted || profile.totalDeliveries,
        todayTasks: profile.todayDeliveries,
        todayEarnings: parseFloat(profile.todayEarnings),
        totalEarnings: parseFloat(profile.totalEarnings),
      },
      vehicle: {
        make: vehicle.make,
        model: vehicle.model,
        year: vehicle.year,
        color: vehicle.color,
        colorEn: vehicle.colorEn,
        licensePlate: vehicle.licensePlate,
        type: vehicle.type,
        typeEn: vehicle.typeEn,
        capacity: vehicle.capacity,
        capacityEn: vehicle.capacityEn,
        photoUrl: vehicle.photoUrl,
      },
      hasActiveOrder: !!formattedActiveOrder,
      activeOrder: formattedActiveOrder,
    });
  } catch (error) {
    console.error('getDashboard error:', error);
    res.status(500).json({
      error: 'Failed to fetch delivery dashboard data'
    });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/delivery/status/:driverId
// ─────────────────────────────────────────────────────────────────────────────
exports.toggleAvailability = async (req, res) => {
  try {
    const {
      driverId
    } = req.params;
    const {
      isOnline
    } = req.body;

    let profile = await DeliveryProfile.findOne({
      where: {
        driverId
      }
    });
    if (!profile) {
      profile = await DeliveryProfile.create({
        driverId,
        isOnline: !!isOnline
      });
    } else {
      await profile.update({
        isOnline: !!isOnline
      });
    }

    res.json({
      message: 'Availability status updated',
      isOnline: profile.isOnline
    });
  } catch (error) {
    console.error('toggleAvailability error:', error);
    res.status(500).json({
      error: 'Failed to update availability status'
    });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/delivery/orders/available
// ─────────────────────────────────────────────────────────────────────────────
exports.getAvailableOrders = async (req, res) => {
  try {
    const orders = await DeliveryOrder.findAll({
      where: {
        status: 'available'
      },
      order: [
        ['postedAt', 'DESC']
      ],
      include: [{
          model: User,
          as: 'customer',
          attributes: ['id', 'name', 'phone', 'city'],
          required: false
        },
        {
          model: User,
          as: 'craftsman',
          attributes: ['id', 'name', 'phone', 'city'],
          required: false
        },
        {
          model: Product,
          as: 'product',
          attributes: ['id', 'titleAr', 'titleEn', 'imageUrl', 'price'],
          required: false
        },
      ],
    });
    res.json(await Promise.all(orders.map(formatDeliveryOrder)));
  } catch (error) {
    console.error('getAvailableOrders error:', error);
    res.status(500).json({
      error: 'Failed to fetch available delivery orders'
    });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/delivery/orders/artisan/:artisanId
// ─────────────────────────────────────────────────────────────────────────────
exports.getOrdersByArtisan = async (req, res) => {
  try {
    const {
      artisanId
    } = req.params;

    if (String(req.user.id) !== String(artisanId) && req.user.role !== 'admin') {
      return res.status(403).json({
        error: 'Forbidden'
      });
    }

    const orders = await DeliveryOrder.findAll({
      where: {
        craftsmanId: artisanId,
        isClearedByArtisan: {
          [Op.ne]: true
        }
      },
      order: [
        ['postedAt', 'DESC']
      ],
      include: [{
          model: User,
          as: 'customer',
          attributes: ['id', 'name', 'phone'],
          required: false
        },
        {
          model: User,
          as: 'driver',
          attributes: ['id', 'name', 'phone', 'email'],
          required: false
        },
      ],
    });

    res.json({
      success: true,
      orders
    });
  } catch (error) {
    console.error('getOrdersByArtisan error:', error);
    res.status(500).json({
      error: 'Failed to fetch artisan delivery orders',
      details: error.message
    });
  }
};

// POST /api/delivery/orders/:id/cancel-by-artisan
exports.cancelDeliveryOrderByArtisan = async (req, res) => {
  try {
    const { id } = req.params;
    const { reason } = req.body;
    const craftsmanId = req.user.id;

    const deliveryOrder = await DeliveryOrder.findByPk(id);
    if (!deliveryOrder) {
      return res.status(404).json({ error: 'Delivery order not found' });
    }

    if (String(deliveryOrder.craftsmanId) !== String(craftsmanId) && req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Forbidden: not your delivery order' });
    }

    if (['completed', 'delivered'].includes(deliveryOrder.status)) {
      return res.status(400).json({ error: 'Cannot cancel an already completed delivery' });
    }

    const assignedDriverId = deliveryOrder.driverId;

    await deliveryOrder.update({
      status: 'cancelled',
      cancelledBy: 'craftsman',
      cancelReason: reason || 'Cancelled by artisan',
    });

    if (assignedDriverId) {
      try {
        await Notification.create({
          userId: assignedDriverId,
          type: 'delivery_cancelled',
          titleEn: 'Delivery Cancelled',
          titleAr: 'تم إلغاء التوصيل',
          bodyEn: `Delivery order ${deliveryOrder.orderCode || ''} was cancelled by artisan.`,
          bodyAr: `تم إلغاء طلب التوصيل ${deliveryOrder.orderCode || ''} من قبل الحرفي.`,
          metadata: { deliveryOrderId: deliveryOrder.id },
        });
      } catch (_) {}
    }

    const ProductOrder = require('../models/Order');
    const CustomOrderRequest = require('../models/CustomOrderRequest');

    let pOrderIds = [];
    if (deliveryOrder.productOrderId) pOrderIds.push(deliveryOrder.productOrderId);
    if (deliveryOrder.relatedOrderIds) {
      try {
        const parsed = JSON.parse(deliveryOrder.relatedOrderIds);
        if (Array.isArray(parsed)) pOrderIds.push(...parsed);
      } catch (_) {}
    }

    for (const pId of pOrderIds) {
      try {
        await ProductOrder.update({ status: 'accepted' }, { where: { id: pId } });
      } catch (_) {}
    }

    let cOrderIds = [];
    if (deliveryOrder.customOrderId) cOrderIds.push(deliveryOrder.customOrderId);
    if (deliveryOrder.relatedCustomOrderIds) {
      try {
        const parsedC = JSON.parse(deliveryOrder.relatedCustomOrderIds);
        if (Array.isArray(parsedC)) cOrderIds.push(...parsedC);
      } catch (_) {}
    }

    for (const cId of cOrderIds) {
      try {
        await CustomOrderRequest.update({ status: 'in_progress' }, { where: { id: cId } });
      } catch (_) {}
    }

    res.json({
      success: true,
      message: 'Delivery order cancelled successfully',
      deliveryOrder,
    });
  } catch (error) {
    console.error('cancelDeliveryOrderByArtisan error:', error);
    res.status(500).json({ error: 'Failed to cancel delivery order', details: error.message });
  }
};

// PATCH /api/delivery/orders/:id/clear-by-artisan
exports.clearDeliveryOrderByArtisan = async (req, res) => {
  try {
    const { id } = req.params;
    const craftsmanId = req.user.id;

    const deliveryOrder = await DeliveryOrder.findByPk(id);
    if (!deliveryOrder) {
      return res.status(404).json({ error: 'Delivery order not found' });
    }

    if (String(deliveryOrder.craftsmanId) !== String(craftsmanId) && req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Forbidden: not your delivery order' });
    }

    await deliveryOrder.update({ isClearedByArtisan: true });

    res.json({
      success: true,
      message: 'Delivery order cleared from history',
      deliveryOrder,
    });
  } catch (error) {
    console.error('clearDeliveryOrderByArtisan error:', error);
    res.status(500).json({ error: 'Failed to clear delivery order', details: error.message });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/delivery/orders/:id/confirm-by-customer
// Customer manually confirms delivery (releases escrow without PIN)
// :id may be the DeliveryOrder id OR the product Order id
// ─────────────────────────────────────────────────────────────────────────────
exports.confirmDeliveryByCustomer = async (req, res) => {
  try {
    const { id } = req.params;
    const customerId = req.user.id;

    // Try to find delivery order directly, or via productOrderId, or via customOrderId
    let deliveryOrder = await DeliveryOrder.findByPk(id);
    if (!deliveryOrder) {
      deliveryOrder = await DeliveryOrder.findOne({ where: { productOrderId: id } });
    }
    if (!deliveryOrder) {
      deliveryOrder = await DeliveryOrder.findOne({ where: { customOrderId: id } });
    }
    if (!deliveryOrder) {
      // Try via relatedOrderIds or relatedCustomOrderIds (grouped orders)
      const allDeliveries = await DeliveryOrder.findAll({
        where: { customerId, status: { [Op.in]: ['available', 'active', 'in_progress', 'accepted', 'delivered'] } }
      });
      for (const d of allDeliveries) {
        let found = false;
        if (d.relatedOrderIds) {
          try {
            const ids = JSON.parse(d.relatedOrderIds);
            if (Array.isArray(ids) && ids.includes(id)) found = true;
          } catch (_) {}
        }
        if (!found && d.relatedCustomOrderIds) {
          try {
            const cids = JSON.parse(d.relatedCustomOrderIds);
            if (Array.isArray(cids) && cids.includes(id)) found = true;
          } catch (_) {}
        }
        if (found) {
          deliveryOrder = d;
          break;
        }
      }
    }

    if (!deliveryOrder) {
      return res.status(404).json({ error: 'Delivery order not found for this order' });
    }

    // Verify this customer owns the delivery
    if (String(deliveryOrder.customerId) !== String(customerId) && req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Forbidden: not your delivery order' });
    }

    if (['completed', 'delivered'].includes(deliveryOrder.status)) {
      return res.status(200).json({
        success: true,
        message: 'Delivery was already completed',
        deliveryOrder,
      });
    }

    // Release escrow and mark all linked orders completed
    const { releaseEscrowAndDistributeShares } = require('../utils/escrowHelper');
    await releaseEscrowAndDistributeShares({
      deliveryOrderId: deliveryOrder.id,
      orderId: deliveryOrder.productOrderId,
    });

    // Notify driver if assigned
    if (deliveryOrder.driverId) {
      try {
        await Notification.create({
          userId: deliveryOrder.driverId,
          type: 'delivery_completed',
          titleEn: 'Delivery completed by customer',
          titleAr: 'تم تأكيد الاستلام من قِبَل العميل',
          bodyEn: `Order ${deliveryOrder.orderCode} was confirmed delivered by the customer.`,
          bodyAr: `تم تأكيد استلام الطلب ${deliveryOrder.orderCode} من قِبَل العميل.`,
          metadata: { deliveryOrderId: deliveryOrder.id },
        });
      } catch (_) {}
    }

    // Notify craftsman
    if (deliveryOrder.craftsmanId) {
      try {
        await Notification.create({
          userId: deliveryOrder.craftsmanId,
          type: 'delivery_completed',
          titleEn: 'Order delivered and confirmed',
          titleAr: 'تم توصيل الطلب وتأكيده',
          bodyEn: `Order ${deliveryOrder.orderCode} has been confirmed delivered by the customer.`,
          bodyAr: `تم تأكيد توصيل الطلب ${deliveryOrder.orderCode} من قِبَل العميل.`,
          metadata: { deliveryOrderId: deliveryOrder.id },
        });
      } catch (_) {}
    }

    res.json({
      success: true,
      message: 'Delivery confirmed successfully by customer',
      deliveryOrder,
    });
  } catch (error) {
    console.error('confirmDeliveryByCustomer error:', error);
    res.status(500).json({ error: 'Failed to confirm delivery', details: error.message });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/delivery/drivers
// ─────────────────────────────────────────────────────────────────────────────
exports.getAvailableDrivers = async (req, res) => {
  try {
    const profiles = await DeliveryProfile.findAll({
      where: {
        isOnline: true,
        isSuspended: false,
        isVerified: true,
      },
      include: [{
        model: User,
        as: 'driver',
        attributes: ['id', 'name', 'phone', 'city', 'email']
      }, ],
      order: [
        ['rating', 'DESC']
      ],
    });

    const drivers = profiles.map((p) => ({
      id: p.driver ? p.driver.id : p.driverId,
      name: p.driver ? p.driver.name : 'Driver',
      phone: p.driver ? p.driver.phone : null,
      city: p.driver ? p.driver.city : null,
      rating: p.rating || 4.9,
    }));

    res.json({
      success: true,
      drivers
    });
  } catch (error) {
    console.error('getAvailableDrivers error:', error);
    res.status(500).json({
      error: 'Failed to fetch drivers',
      details: error.message
    });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/delivery/orders/:id/assign-driver
// ─────────────────────────────────────────────────────────────────────────────
exports.assignDriverToOrder = async (req, res) => {
  try {
    const {
      id
    } = req.params;
    const {
      driverId
    } = req.body;

    const order = await DeliveryOrder.findByPk(id);
    if (!order) return res.status(404).json({
      error: 'Delivery order not found'
    });

    if (String(req.user.id) !== String(order.craftsmanId) && req.user.role !== 'admin') {
      return res.status(403).json({
        error: 'Forbidden'
      });
    }

    await order.update({
      driverId,
      status: 'active'
    });

    try {
      if (driverId) {
        await Notification.create({
          userId: driverId,
          type: 'delivery_assigned',
          titleEn: 'New delivery assigned',
          titleAr: 'تم تعيين توصيل جديد',
          bodyEn: `You have been assigned delivery ${order.orderCode}`,
          bodyAr: `تم تعيين التسليم ${order.orderCode} لك`,
          metadata: {
            deliveryOrderId: order.id
          },
        });
      }
    } catch (e) {
      console.error('notify driver error:', e.message || e);
    }

    res.json({
      success: true,
      message: 'Driver assigned',
      order
    });
  } catch (error) {
    console.error('assignDriverToOrder error:', error);
    res.status(500).json({
      error: 'Failed to assign driver',
      details: error.message
    });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/delivery/orders/driver/:driverId
// ─────────────────────────────────────────────────────────────────────────────
exports.getDriverOrders = async (req, res) => {
  try {
    const {
      driverId
    } = req.params;
    const {
      status
    } = req.query;

    const whereClause = {
      driverId
    };
    if (status) {
      if (status === 'delivered' || status === 'completed') {
        whereClause.status = {
          [Op.in]: ['delivered', 'completed']
        };
      } else if (status === 'active') {
        whereClause.status = {
          [Op.in]: ['active', 'in_progress']
        };
      } else {
        whereClause.status = status;
      }
    }

    const orders = await DeliveryOrder.findAll({
      where: whereClause,
      order: [
        ['createdAt', 'DESC']
      ],
      include: [{
          model: User,
          as: 'customer',
          attributes: ['id', 'name', 'phone', 'city'],
          required: false
        },
        {
          model: User,
          as: 'craftsman',
          attributes: ['id', 'name', 'phone', 'city'],
          required: false
        },
        {
          model: Product,
          as: 'product',
          attributes: ['id', 'titleAr', 'titleEn', 'imageUrl', 'price'],
          required: false
        },
      ],
    });

    res.json(await Promise.all(orders.map(formatDeliveryOrder)));
  } catch (error) {
    console.error('getDriverOrders error:', error);
    res.status(500).json({
      error: 'Failed to fetch driver delivery orders'
    });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/delivery/orders/:id
// ─────────────────────────────────────────────────────────────────────────────
exports.getOrderById = async (req, res) => {
  try {
    const {
      id
    } = req.params;

    const order = await DeliveryOrder.findByPk(id, {
      include: [{
          model: User,
          as: 'customer',
          attributes: ['id', 'name', 'phone', 'city', 'email'],
          required: false
        },
        {
          model: User,
          as: 'craftsman',
          attributes: ['id', 'name', 'phone', 'city', 'email'],
          required: false
        },
        {
          model: Product,
          as: 'product',
          attributes: ['id', 'titleAr', 'titleEn', 'imageUrl', 'price'],
          required: false
        },
      ],
    });

    if (!order) {
      return res.status(404).json({
        message: 'Delivery order not found'
      });
    }

    res.status(200).json(await formatDeliveryOrder(order));
  } catch (error) {
    console.error('Error fetching order details:', error);
    res.status(500).json({
      message: 'Failed to fetch order details',
      error: error.message
    });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/delivery/orders/:id/accept
// ─────────────────────────────────────────────────────────────────────────────
exports.acceptOrder = async (req, res) => {
  try {
    const {
      id
    } = req.params;
    const {
      driverId
    } = req.body;

    const order = await DeliveryOrder.findByPk(id);
    if (!order) {
      return res.status(404).json({
        error: 'Delivery order not found'
      });
    }

    if (order.status !== 'available') {
      return res.status(400).json({
        error: 'Order is no longer available'
      });
    }

    await order.update({
      driverId,
      status: 'active',
    });

    res.json({
      message: 'Order accepted successfully',
      order
    });
  } catch (error) {
    console.error('acceptOrder error:', error);
    res.status(500).json({
      error: 'Failed to accept order'
    });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/delivery/orders/:id/status
// ─────────────────────────────────────────────────────────────────────────────
exports.updateOrderStatus = async (req, res) => {
  try {
    const {
      id
    } = req.params;
    const {
      status,
      issueType,
      issueNotes,
      issuePhotoUrl,
      cancelReason,
      cancelledBy
    } = req.body;

    const order = await DeliveryOrder.findByPk(id);
    if (!order) {
      return res.status(404).json({
        error: 'Delivery order not found'
      });
    }

    const updates = {
      status
    };

    if (status === 'delivered') {
      updates.deliveredAt = new Date();
    } else if (status === 'undelivered' || status === 'returned') {
      if (issueType) updates.issueType = issueType;
      if (issueNotes) updates.issueNotes = issueNotes;
      if (issuePhotoUrl) updates.issuePhotoUrl = issuePhotoUrl;
    } else if (status === 'cancelled') {
      updates.cancelReason = cancelReason || issueNotes || issueType || 'Cancelled by driver';
      updates.cancelledBy = cancelledBy || 'driver';
      if (issueType) updates.issueType = issueType;
      if (issueNotes) updates.issueNotes = issueNotes;
    }

    await order.update(updates);

    res.json({
      message: `Order status updated to ${status}`,
      order,
    });
  } catch (error) {
    console.error('updateOrderStatus error:', error);
    res.status(500).json({
      error: 'Failed to update order status'
    });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/delivery/orders/:id/verify-pin
// ─────────────────────────────────────────────────────────────────────────────
exports.verifyDeliveryPinOrQR = async (req, res) => {
  try {
    const {
      id
    } = req.params;
    const {
      pin,
      qrData
    } = req.body;

    let order = await DeliveryOrder.findByPk(id);
    if (!order) {
      order = await DeliveryOrder.findOne({
        where: {
          productOrderId: id
        }
      });
    }
    if (!order) {
      return res.status(404).json({
        error: 'Delivery order not found'
      });
    }

    const providedPin = String(pin || qrData || '').trim();
    const expectedPin = String(order.deliveryPin || '').trim();

    if (providedPin !== expectedPin && !providedPin.includes(expectedPin)) {
      return res.status(400).json({
        error: 'Invalid delivery PIN code or QR data',
        success: false,
      });
    }

    // ── Release Escrow & Distribute Shares (Artisan, Driver, Platform) ─────────
    const { releaseEscrowAndDistributeShares } = require('../utils/escrowHelper');
    await releaseEscrowAndDistributeShares({
      deliveryOrderId: order.id,
      orderId: order.productOrderId,
    });

    // ─── Create notifications for driver and customer ────────────────
    try {
      await Notification.create({
        userId: order.driverId,
        type: 'delivery_completed',
        titleEn: 'Delivery completed',
        titleAr: 'تم إنجاز التوصيل',
        bodyEn: `You delivered order ${order.orderCode}`,
        bodyAr: `قمت بتوصيل الطلب ${order.orderCode}`,
        metadata: {
          deliveryOrderId: order.id
        },
      });

      await Notification.create({
        userId: order.customerId,
        type: 'delivery_completed',
        titleEn: 'Your order has been delivered',
        titleAr: 'تم توصيل طلبك',
        bodyEn: `Order ${order.orderCode} delivered successfully.`,
        bodyAr: `تم توصيل الطلب ${order.orderCode} بنجاح.`,
        metadata: {
          deliveryOrderId: order.id
        },
      });
    } catch (notifErr) {
      console.error('Failed to create delivery notifications:', notifErr.message || notifErr);
    }

    return res.json({
      success: true,
      message: 'Delivery verified successfully! Order completed.',
      order,
      productOrderUpdated,
      escrowReleased,
    });
  } catch (error) {
    console.error('verifyDeliveryPinOrQR error:', error);
    return res.status(500).json({
      error: 'Failed to verify delivery PIN',
      details: error.message,
    });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/delivery/earnings/:driverId
// ─────────────────────────────────────────────────────────────────────────────
exports.getEarnings = async (req, res) => {
  try {
    const {
      driverId
    } = req.params;

    let profile = await DeliveryProfile.findOne({
      where: {
        driverId
      }
    });
    if (!profile) profile = await DeliveryProfile.create({
      driverId
    });

    // Calculate total earnings from delivered escrow orders
    const allDeliveredOrders = await DeliveryOrder.findAll({
      where: {
        driverId,
        status: { [Op.in]: ['delivered', 'completed'] },
      },
    });

    const totalDeliveredEarnings = allDeliveredOrders.reduce(
      (sum, ord) => sum + (parseFloat(ord.earningAmount) || 0),
      0
    );

    // Real payout history
    const realPayoutHistory = await Payout.findAll({
      where: {
        driverId
      },
      order: [
        ['requestedAt', 'DESC']
      ],
    });

    const totalPayouts = realPayoutHistory
      .filter((p) => p.status === 'completed' || p.status === 'approved')
      .reduce((sum, p) => sum + (parseFloat(p.amount) || 0), 0);

    const balance = Math.max(0, totalDeliveredEarnings - totalPayouts);

    if (profile && profile.totalEarnings !== balance) {
      await profile.update({ totalEarnings: balance });
    }

    const payoutHistory = realPayoutHistory.map(p => ({
      date: p.requestedAt.toISOString().split('T')[0],
      amount: p.amount,
      status: p.status,
    }));

    // Real weekly earnings (sum of completed deliveries in last 7 days)
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
    const completedOrders = await DeliveryOrder.findAll({
      where: {
        driverId,
        status: 'delivered',
        deliveredAt: {
          [Op.gte]: sevenDaysAgo
        },
      },
    });
    // Group by day of week (Mon-Sun)
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const weeklyMap = {};
    days.forEach(d => weeklyMap[d] = 0);
    completedOrders.forEach(order => {
      const dayIndex = order.deliveredAt.getDay(); // 0=Sun, 1=Mon, ...
      const dayName = days[(dayIndex + 6) % 7]; // convert to Mon=0
      weeklyMap[dayName] += parseFloat(order.earningAmount || 0);
    });
    const weeklyEarnings = days.map(day => ({
      day,
      amount: weeklyMap[day]
    }));

    // Real breakdown – you can compute from actual data, or keep mock
    const breakdown = [{
        label: 'الأساسي',
        labelEn: 'Base Pay',
        amount: balance * 0.8,
        color: '#D4A017'
      },
      {
        label: 'المكافآت',
        labelEn: 'Bonuses',
        amount: 45,
        color: '#4CAF50'
      },
      {
        label: 'الخصومات',
        labelEn: 'Deductions',
        amount: -15,
        color: '#F44336'
      },
    ];

    res.json({
      balance,
      todayEarnings: parseFloat(profile.todayEarnings || 0),
      weeklyEarnings,
      breakdown,
      payoutHistory,
      hasStripeAccount: !!profile.connectedAccountId,
      bankAccount: profile.bankAccount || null, // if you store bank info
    });
  } catch (error) {
    console.error('getEarnings error:', error);
    res.status(500).json({
      error: 'Failed to fetch earnings'
    });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/delivery/vehicle/:driverId
// ─────────────────────────────────────────────────────────────────────────────
exports.getVehicle = async (req, res) => {
  try {
    const {
      driverId
    } = req.params;

    let vehicle = await DeliveryVehicle.findOne({
      where: {
        driverId
      }
    });
    if (!vehicle) {
      vehicle = await DeliveryVehicle.create({
        driverId
      });
    }

    res.json(vehicle);
  } catch (error) {
    console.error('getVehicle error:', error);
    res.status(500).json({
      error: 'Failed to fetch vehicle information'
    });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// PUT /api/delivery/vehicle/:driverId
// ─────────────────────────────────────────────────────────────────────────────
exports.updateVehicle = async (req, res) => {
  try {
    const {
      driverId
    } = req.params;
    const {
      make,
      model,
      year,
      color,
      colorEn,
      licensePlate,
      type,
      typeEn,
      capacity,
      capacityEn,
      photoUrl,
    } = req.body;

    let vehicle = await DeliveryVehicle.findOne({
      where: {
        driverId
      }
    });
    if (!vehicle) {
      vehicle = await DeliveryVehicle.create({
        driverId,
        ...req.body
      });
    } else {
      await vehicle.update({
        ...(make !== undefined && {
          make
        }),
        ...(model !== undefined && {
          model
        }),
        ...(year !== undefined && {
          year
        }),
        ...(color !== undefined && {
          color
        }),
        ...(colorEn !== undefined && {
          colorEn
        }),
        ...(licensePlate !== undefined && {
          licensePlate
        }),
        ...(type !== undefined && {
          type
        }),
        ...(typeEn !== undefined && {
          typeEn
        }),
        ...(capacity !== undefined && {
          capacity
        }),
        ...(capacityEn !== undefined && {
          capacityEn
        }),
        ...(photoUrl !== undefined && {
          photoUrl
        }),
      });
    }

    res.json({
      message: 'Vehicle details updated successfully',
      vehicle
    });
  } catch (error) {
    console.error('updateVehicle error:', error);
    res.status(500).json({
      error: 'Failed to update vehicle details'
    });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/delivery/profile/:driverId
// ─────────────────────────────────────────────────────────────────────────────
exports.getProfile = async (req, res) => {
  try {
    const {
      driverId
    } = req.params;

    const user = await User.findByPk(driverId, {
      attributes: ['id', 'name', 'email', 'city', 'profileImage'],
    });

    if (!user) {
      return res.status(404).json({
        error: 'Driver user not found'
      });
    }

    let profile = await DeliveryProfile.findOne({
      where: {
        driverId
      }
    });
    if (!profile) {
      profile = await DeliveryProfile.create({
        driverId
      });
    }

    res.json({
      user,
      profile,
    });
  } catch (error) {
    console.error('getProfile error:', error);
    res.status(500).json({
      error: 'Failed to fetch driver profile'
    });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// PUT /api/delivery/profile/:driverId
// ─────────────────────────────────────────────────────────────────────────────
exports.updateProfile = async (req, res) => {
  try {
    const {
      driverId
    } = req.params;
    const {
      name,
      city,
      profileImage
    } = req.body;

    const user = await User.findByPk(driverId);
    if (!user) {
      return res.status(404).json({
        error: 'Driver user not found'
      });
    }

    await user.update({
      ...(name !== undefined && {
        name
      }),
      ...(city !== undefined && {
        city
      }),
      ...(profileImage !== undefined && {
        profileImage
      }),
    });

    res.json({
      message: 'Driver profile updated',
      user
    });
  } catch (error) {
    console.error('updateProfile error:', error);
    res.status(500).json({
      error: 'Failed to update driver profile'
    });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/delivery/notifications/:userId
// ─────────────────────────────────────────────────────────────────────────────
exports.getUserNotifications = async (req, res) => {
  try {
    const {
      userId
    } = req.params;

    const notifications = await Notification.findAll({
      where: {
        userId
      },
      order: [
        ['createdAt', 'DESC']
      ],
    });

    res.json(notifications);
  } catch (error) {
    console.error('getUserNotifications error:', error);
    res.status(500).json({
      error: 'Failed to fetch notifications'
    });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/delivery/notifications/:id/read
// ─────────────────────────────────────────────────────────────────────────────
exports.markAsRead = async (req, res) => {
  try {
    const {
      id
    } = req.params;

    const notification = await Notification.findByPk(id);
    if (!notification) {
      return res.status(404).json({
        error: 'Notification not found'
      });
    }

    await notification.update({
      isRead: true
    });

    res.json({
      message: 'Notification marked as read',
      notification
    });
  } catch (error) {
    console.error('markAsRead error:', error);
    res.status(500).json({
      error: 'Failed to update notification status'
    });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/delivery/sos
// ─────────────────────────────────────────────────────────────────────────────
const DeliveryIssue = require('../models/DeliveryIssue');

exports.triggerSOS = async (req, res) => {
  try {
    const {
      driverId,
      location,
      orderId,
      notes
    } = req.body;

    const issue = await DeliveryIssue.create({
      driverId: driverId || req.user?.id,
      orderId: orderId || null,
      issueType: 'sos',
      description: `Emergency SOS Alert! Location: ${location || 'Unknown Location'}`,
      status: 'new',
      reportedBy: 'driver',
      notes: notes || 'Driver pressed emergency SOS button',
    });

    res.status(201).json({
      message: 'SOS Alert triggered successfully',
      issue,
    });
  } catch (error) {
    console.error('triggerSOS error:', error);
    res.status(500).json({
      error: 'Failed to trigger SOS alert'
    });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/delivery/orders
// ─────────────────────────────────────────────────────────────────────────────
exports.createDeliveryOrder = async (req, res) => {
  try {
    const {
      orderId, // single ready‑made product order ID
      customOrderId, // single custom order ID
      orderIds, // array or JSON string of product order IDs to group
      customOrderIds, // array or JSON string of custom order IDs to group
      productId,
      pickupAddress,
      dropoffAddress,
      customerPhone,
      pickupPhone,
      weightKg,
      isFragile,
      earningAmount,
      driverId,
      dueDate,
    } = req.body;

    const craftsmanId = req.user.id;

    let allOrderIds = [];
    if (orderId) allOrderIds.push(String(orderId));
    if (Array.isArray(orderIds)) {
      allOrderIds.push(...orderIds.map(id => String(id)));
    } else if (typeof orderIds === 'string') {
      try {
        const parsed = JSON.parse(orderIds);
        if (Array.isArray(parsed)) allOrderIds.push(...parsed.map(id => String(id)));
      } catch (_) {
        if (orderIds.trim()) allOrderIds.push(orderIds.trim());
      }
    }
    allOrderIds = Array.from(new Set(allOrderIds.filter(Boolean)));

    let allCustomOrderIds = [];
    if (customOrderId) allCustomOrderIds.push(String(customOrderId));
    if (Array.isArray(customOrderIds)) {
      allCustomOrderIds.push(...customOrderIds.map(id => String(id)));
    } else if (typeof customOrderIds === 'string') {
      try {
        const parsedC = JSON.parse(customOrderIds);
        if (Array.isArray(parsedC)) allCustomOrderIds.push(...parsedC.map(id => String(id)));
      } catch (_) {
        if (customOrderIds.trim()) allCustomOrderIds.push(customOrderIds.trim());
      }
    }
    allCustomOrderIds = Array.from(new Set(allCustomOrderIds.filter(Boolean)));

    let targetDropoffAddress = dropoffAddress;
    let targetCustomerPhone = customerPhone;
    let targetCustomerId = null;

    const ProductOrder = require('../models/Order');
    const CustomOrderRequest = require('../models/CustomOrderRequest');

    for (const pId of allOrderIds) {
      try {
        const pOrd = await ProductOrder.findByPk(pId);
        if (pOrd) {
          if (!targetDropoffAddress) targetDropoffAddress = pOrd.shippingAddress;
          if (!targetCustomerPhone) targetCustomerPhone = pOrd.customerPhone;
          if (!targetCustomerId) targetCustomerId = pOrd.customerId;
        }
      } catch (_) {}
    }

    for (const cId of allCustomOrderIds) {
      try {
        const cReq = await CustomOrderRequest.findByPk(cId);
        if (cReq) {
          if (!targetDropoffAddress) targetDropoffAddress = cReq.deliveryAddress;
          if (!targetCustomerPhone) targetCustomerPhone = cReq.customerPhone;
          if (!targetCustomerId) targetCustomerId = cReq.customerId;
        }
      } catch (_) {}
    }

    if (!pickupAddress || !targetDropoffAddress) {
      return res.status(400).json({
        error: 'Pickup and dropoff addresses are required'
      });
    }

    // ── Check if an active delivery order already exists for this craftsman ──
    const existingActiveOrders = await DeliveryOrder.findAll({
      where: {
        craftsmanId,
        status: {
          [Op.in]: ['available', 'active', 'in_progress']
        }
      }
    });

    let existingActiveDelivery = null;
    for (const ext of existingActiveOrders) {
      let extPIds = ext.productOrderId ? [String(ext.productOrderId)] : [];
      if (ext.relatedOrderIds) {
        try {
          const parsed = JSON.parse(ext.relatedOrderIds);
          if (Array.isArray(parsed)) extPIds.push(...parsed.map(String));
        } catch (_) {}
      }

      let extCIds = ext.customOrderId ? [String(ext.customOrderId)] : [];
      if (ext.relatedCustomOrderIds) {
        try {
          const parsedC = JSON.parse(ext.relatedCustomOrderIds);
          if (Array.isArray(parsedC)) extCIds.push(...parsedC.map(String));
        } catch (_) {}
      }

      const hasMatchingProductOrder = allOrderIds.some(id => extPIds.includes(id));
      const hasMatchingCustomOrder = allCustomOrderIds.some(id => extCIds.includes(id));

      if (hasMatchingProductOrder || hasMatchingCustomOrder) {
        existingActiveDelivery = ext;
        break;
      }
    }

    if (existingActiveDelivery) {
      let mergedPIds = [];
      if (existingActiveDelivery.productOrderId) mergedPIds.push(String(existingActiveDelivery.productOrderId));
      if (existingActiveDelivery.relatedOrderIds) {
        try {
          const parsed = JSON.parse(existingActiveDelivery.relatedOrderIds);
          if (Array.isArray(parsed)) mergedPIds.push(...parsed.map(String));
        } catch (_) {}
      }
      mergedPIds.push(...allOrderIds);
      mergedPIds = Array.from(new Set(mergedPIds.filter(Boolean)));

      let mergedCIds = [];
      if (existingActiveDelivery.customOrderId) mergedCIds.push(String(existingActiveDelivery.customOrderId));
      if (existingActiveDelivery.relatedCustomOrderIds) {
        try {
          const parsedC = JSON.parse(existingActiveDelivery.relatedCustomOrderIds);
          if (Array.isArray(parsedC)) mergedCIds.push(...parsedC.map(String));
        } catch (_) {}
      }
      mergedCIds.push(...allCustomOrderIds);
      mergedCIds = Array.from(new Set(mergedCIds.filter(Boolean)));

      await existingActiveDelivery.update({
        pickupAddress,
        pickupPhone: pickupPhone || existingActiveDelivery.pickupPhone || '',
        dropoffAddress: targetDropoffAddress,
        customerPhone: targetCustomerPhone,
        weightKg: weightKg || existingActiveDelivery.weightKg || 0,
        isFragile: isFragile !== undefined ? isFragile : existingActiveDelivery.isFragile,
        earningAmount: earningAmount !== undefined ? earningAmount : existingActiveDelivery.earningAmount,
        driverId: driverId || existingActiveDelivery.driverId || null,
        status: (driverId || existingActiveDelivery.driverId) ? 'active' : existingActiveDelivery.status,
        relatedOrderIds: JSON.stringify(mergedPIds),
        relatedCustomOrderIds: JSON.stringify(mergedCIds),
        isClearedByArtisan: false,
      });

      for (const pId of mergedPIds) {
        try { await ProductOrder.update({ status: 'waiting_delivery' }, { where: { id: pId } }); } catch (_) {}
      }
      for (const cId of mergedCIds) {
        try { await CustomOrderRequest.update({ status: 'in_progress' }, { where: { id: cId } }); } catch (_) {}
      }

      return res.status(200).json({
        success: true,
        message: 'Delivery order updated successfully',
        deliveryOrder: existingActiveDelivery,
      });
    }

    // ── Generate PIN and QR data for new DeliveryOrder ──
    const deliveryPin = String(1000 + Math.floor(Math.random() * 9000));
    const orderCode = 'DEL-' + Date.now().toString(36).toUpperCase();
    const qrData = `DELIVERY:${orderCode}:${Date.now()}`;
    const initialStatus = driverId ? 'active' : 'available';

    let orderType = 'ready_made';
    if (allCustomOrderIds.length > 0) orderType = 'custom_made';

    const deliveryOrder = await DeliveryOrder.create({
      orderCode,
      customerId: targetCustomerId,
      craftsmanId,
      driverId: driverId || null,
      productId: productId || null,
      productOrderId: allOrderIds[0] || null,
      customOrderId: allCustomOrderIds[0] || null,
      relatedOrderIds: JSON.stringify(allOrderIds),
      relatedCustomOrderIds: JSON.stringify(allCustomOrderIds),
      orderType,
      customSpecifications: null,
      status: initialStatus,
      pickupAddress,
      pickupPhone: pickupPhone || '',
      dropoffAddress: targetDropoffAddress,
      customerPhone: targetCustomerPhone,
      earningAmount: earningAmount || 0,
      weightKg: weightKg || 0,
      isFragile: isFragile || false,
      dueAt: dueDate || null,
      deliveryPin,
      qrCodeData: qrData,
      isClearedByArtisan: false,
    });

    if (driverId) {
      try {
        await Notification.create({
          userId: driverId,
          type: 'delivery_available',
          titleEn: 'New delivery available',
          titleAr: 'توصيل جديد متاح',
          bodyEn: `Pickup from ${pickupAddress}`,
          bodyAr: `استلام من ${pickupAddress}`,
          metadata: { deliveryOrderId: deliveryOrder.id },
        });
      } catch (_) {}
    }

    if (targetCustomerId) {
      try {
        const orderRef = `الطلب #${deliveryOrder.orderCode || deliveryOrder.id.substring(0, 8)}`;
        const orderRefEn = `Order #${deliveryOrder.orderCode || deliveryOrder.id.substring(0, 8)}`;

        await Notification.create({
          userId: targetCustomerId,
          type: 'delivery_created',
          titleEn: `Delivery PIN Code 🚚`,
          titleAr: `رمز استلام الشحنة 🚚`,
          bodyEn: `Delivery started for ${orderRefEn}! Your Delivery PIN to share with the driver is: ${deliveryPin}`,
          bodyAr: `تم إنشاء شحنة توصيل لـ ${orderRef}! رمز التسليم الخاص بك للمندوب هو: [ ${deliveryPin} ]`,
          metadata: {
            deliveryOrderId: deliveryOrder.id,
            deliveryPin,
            orderCode: deliveryOrder.orderCode,
          },
        });
      } catch (_) {}
    }

    for (const pId of allOrderIds) {
      try { await ProductOrder.update({ status: 'waiting_delivery' }, { where: { id: pId } }); } catch (_) {}
    }
    for (const cId of allCustomOrderIds) {
      try { await CustomOrderRequest.update({ status: 'in_progress' }, { where: { id: cId } }); } catch (_) {}
    }

    res.status(201).json({
      success: true,
      message: 'Delivery order created successfully',
      deliveryOrder: {
        ...deliveryOrder.toJSON(),
        deliveryPin,
        qrCodeData: qrData,
      },
    });
  } catch (error) {
    console.error('createDeliveryOrder error:', error);
    res.status(500).json({
      error: 'Failed to create delivery order',
      details: error.message,
    });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/delivery/payout/request
// ─────────────────────────────────────────────────────────────────────────────
exports.requestPayout = async (req, res) => {
  try {
    const {
      driverId,
      amount
    } = req.body;
    if (!driverId || !amount || amount <= 0) {
      return res.status(400).json({
        error: 'Invalid driver ID or amount'
      });
    }

    const driver = await User.findByPk(driverId);
    if (!driver) {
      return res.status(404).json({
        error: 'Driver not found'
      });
    }

    let profile = await DeliveryProfile.findOne({
      where: {
        driverId
      }
    });
    if (!profile) {
      profile = await DeliveryProfile.create({
        driverId
      });
    }

    const availableBalance = parseFloat(profile.totalEarnings || 0);
    const requestedAmount = parseFloat(amount);
    if (requestedAmount > availableBalance) {
      return res.status(400).json({
        error: 'Insufficient balance'
      });
    }

    const connectedAccountId = profile.connectedAccountId;
    if (!connectedAccountId) {
      return res.status(400).json({
        error: 'Driver has not onboarded with Stripe. Please onboard first.',
        onboardRequired: true,
      });
    }

    const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
    let transfer;
    try {
      const transferAmountInCents = Math.round((requestedAmount / Number(process.env.JOD_PER_USD || 3.1122)) * 100);
      transfer = await stripe.transfers.create({
        amount: transferAmountInCents,
        currency: 'usd',
        destination: connectedAccountId,
        description: `Payout to driver ${driverId} for ${requestedAmount} JOD`,
      });
    } catch (stripeError) {
      console.error('[Stripe Transfer Error]', stripeError.message);
      return res.status(500).json({
        error: 'Stripe transfer failed',
        details: stripeError.message,
      });
    }

    await profile.update({
      totalEarnings: availableBalance - requestedAmount,
    });

    const payout = await Payout.create({
      driverId,
      amount: requestedAmount,
      stripeTransferId: transfer.id,
      status: 'completed',
      completedAt: new Date(),
    });

    await Notification.create({
      userId: driverId,
      type: 'payout',
      titleEn: 'Payout Completed',
      titleAr: 'تم إتمام السحب',
      bodyEn: `Successfully transferred ${requestedAmount} JOD to your bank account.`,
      bodyAr: `تم تحويل ${requestedAmount} دينار إلى حسابك البنكي بنجاح.`,
    });

    res.json({
      success: true,
      message: 'Payout successful',
      payout,
      newBalance: profile.totalEarnings,
    });
  } catch (error) {
    console.error('[requestPayout] ERROR:', error);
    res.status(500).json({
      error: 'Failed to process payout',
      details: error.message,
    });
  }
};


// const {
//   Op
// } = require('sequelize');
// const DeliveryProfile = require('../models/DeliveryProfile');
// const DeliveryVehicle = require('../models/DeliveryVehicle');
// const DeliveryOrder = require('../models/DeliveryOrder');
// const DeliveryPayment = require('../models/DeliveryPayment');
// const Notification = require('../models/Notification');
// const User = require('../models/User');
// const Product = require('../models/Product');
// const Payout = require('../models/Payout');


// // ─────────────────────────────────────────────────────────────────────────────
// // GET /api/delivery/dashboard/:driverId
// // Fetch driver statistics, availability status, vehicle info, and active order
// // ─────────────────────────────────────────────────────────────────────────────
// exports.getDashboard = async (req, res) => {
//   try {
//     const {
//       driverId
//     } = req.params;

//     // Find or create profile
//     let profile = await DeliveryProfile.findOne({
//       where: {
//         driverId
//       }
//     });
//     if (!profile) {
//       profile = await DeliveryProfile.create({
//         driverId
//       });
//     }

//     // Find vehicle
//     let vehicle = await DeliveryVehicle.findOne({
//       where: {
//         driverId
//       }
//     });
//     if (!vehicle) {
//       vehicle = await DeliveryVehicle.create({
//         driverId
//       });
//     }

//     // Counts & Stats
//     const totalCompleted = await DeliveryOrder.count({
//       where: {
//         driverId,
//         status: {
//           [Op.in]: ['completed', 'delivered']
//         }
//       },
//     });

//     const activeOrder = await DeliveryOrder.findOne({
//       where: {
//         driverId,
//         status: {
//           [Op.in]: ['active', 'in_progress']
//         }
//       },
//       order: [
//         ['updatedAt', 'DESC']
//       ],
//       include: [{
//           model: User,
//           as: 'customer',
//           attributes: ['id', 'name', 'phone', 'city'],
//           required: false
//         },
//         {
//           model: User,
//           as: 'craftsman',
//           attributes: ['id', 'name', 'phone', 'city'],
//           required: false
//         },
//         {
//           model: Product,
//           as: 'product',
//           attributes: ['id', 'titleAr', 'titleEn', 'imageUrl', 'price'],
//           required: false
//         },
//       ],
//     });

//     res.json({
//       isOnline: profile.isOnline,
//       isSuspended: profile.isSuspended || false,
//       rating: profile.rating,
//       stats: {
//         totalCompleted: totalCompleted || profile.totalDeliveries,
//         todayTasks: profile.todayDeliveries,
//         todayEarnings: parseFloat(profile.todayEarnings),
//         totalEarnings: parseFloat(profile.totalEarnings),
//       },
//       vehicle: {
//         make: vehicle.make,
//         model: vehicle.model,
//         year: vehicle.year,
//         color: vehicle.color,
//         colorEn: vehicle.colorEn,
//         licensePlate: vehicle.licensePlate,
//         type: vehicle.type,
//         typeEn: vehicle.typeEn,
//         capacity: vehicle.capacity,
//         capacityEn: vehicle.capacityEn,
//         photoUrl: vehicle.photoUrl,
//       },
//       hasActiveOrder: !!activeOrder,
//       activeOrder,
//     });
//   } catch (error) {
//     console.error('getDashboard error:', error);
//     res.status(500).json({
//       error: 'Failed to fetch delivery dashboard data'
//     });
//   }
// };

// // ─────────────────────────────────────────────────────────────────────────────
// // PATCH /api/delivery/status/:driverId
// // Toggle driver online/offline availability state
// // ─────────────────────────────────────────────────────────────────────────────
// exports.toggleAvailability = async (req, res) => {
//   try {
//     const {
//       driverId
//     } = req.params;
//     const {
//       isOnline
//     } = req.body;

//     let profile = await DeliveryProfile.findOne({
//       where: {
//         driverId
//       }
//     });
//     if (!profile) {
//       profile = await DeliveryProfile.create({
//         driverId,
//         isOnline: !!isOnline
//       });
//     } else {
//       await profile.update({
//         isOnline: !!isOnline
//       });
//     }

//     res.json({
//       message: 'Availability status updated',
//       isOnline: profile.isOnline
//     });
//   } catch (error) {
//     console.error('toggleAvailability error:', error);
//     res.status(500).json({
//       error: 'Failed to update availability status'
//     });
//   }
// };

// // ─────────────────────────────────────────────────────────────────────────────
// // GET /api/delivery/orders/available
// // Get list of orders available for pickup by drivers
// // ─────────────────────────────────────────────────────────────────────────────
// exports.getAvailableOrders = async (req, res) => {
//   try {
//     const orders = await DeliveryOrder.findAll({
//       where: {
//         status: 'available'
//       },
//       order: [
//         ['postedAt', 'DESC']
//       ],
//     });
//     res.json(orders);
//   } catch (error) {
//     console.error('getAvailableOrders error:', error);
//     res.status(500).json({
//       error: 'Failed to fetch available delivery orders'
//     });
//   }
// };

// // GET /api/delivery/orders/artisan/:artisanId
// // Get delivery orders for a specific artisan (craftsman)
// exports.getOrdersByArtisan = async (req, res) => {
//   try {
//     const {
//       artisanId
//     } = req.params;

//     // Only allow the artisan themselves or admin users
//     if (String(req.user.id) !== String(artisanId) && req.user.role !== 'admin') {
//       return res.status(403).json({
//         error: 'Forbidden'
//       });
//     }

//     const orders = await DeliveryOrder.findAll({
//       where: {
//         craftsmanId: artisanId
//       },
//       order: [
//         ['postedAt', 'DESC']
//       ],
//       include: [{
//           model: User,
//           as: 'customer',
//           attributes: ['id', 'name', 'phone'],
//           required: false
//         },
//         {
//           model: User,
//           as: 'driver',
//           attributes: ['id', 'name', 'phone', 'email'],
//           required: false
//         },
//       ],
//     });

//     res.json({
//       success: true,
//       orders
//     });
//   } catch (error) {
//     console.error('getOrdersByArtisan error:', error);
//     res.status(500).json({
//       error: 'Failed to fetch artisan delivery orders',
//       details: error.message
//     });
//   }
// };

// // GET /api/delivery/drivers
// // Return a list of available drivers for assignment (public to authenticated users)
// exports.getAvailableDrivers = async (req, res) => {
//   try {
//     const profiles = await DeliveryProfile.findAll({
//       where: {
//         isOnline: true,
//         isSuspended: false,
//         isVerified: true,
//       },
//       include: [{
//         model: User,
//         as: 'driver',
//         attributes: ['id', 'name', 'phone', 'city', 'email']
//       }, ],
//       order: [
//         ['rating', 'DESC']
//       ],
//     });

//     const drivers = profiles.map((p) => ({
//       id: p.driver ? p.driver.id : p.driverId,
//       name: p.driver ? p.driver.name : 'Driver',
//       phone: p.driver ? p.driver.phone : null,
//       city: p.driver ? p.driver.city : null,
//       rating: p.rating || 4.9,
//     }));

//     res.json({
//       success: true,
//       drivers
//     });
//   } catch (error) {
//     console.error('getAvailableDrivers error:', error);
//     res.status(500).json({
//       error: 'Failed to fetch drivers',
//       details: error.message
//     });
//   }
// };

// // POST /api/delivery/orders/:id/assign-driver
// // Artisan assigns a driver to their delivery order
// exports.assignDriverToOrder = async (req, res) => {
//   try {
//     const {
//       id
//     } = req.params;
//     const {
//       driverId
//     } = req.body;

//     const order = await DeliveryOrder.findByPk(id);
//     if (!order) return res.status(404).json({
//       error: 'Delivery order not found'
//     });

//     // Only the craftsman who owns the order or admin can assign a driver
//     if (String(req.user.id) !== String(order.craftsmanId) && req.user.role !== 'admin') {
//       return res.status(403).json({
//         error: 'Forbidden'
//       });
//     }

//     await order.update({
//       driverId,
//       status: 'active'
//     });

//     // Notify the driver if exists
//     try {
//       if (driverId) {
//         await Notification.create({
//           userId: driverId,
//           type: 'delivery_assigned',
//           titleEn: 'New delivery assigned',
//           titleAr: 'تم تعيين توصيل جديد',
//           bodyEn: `You have been assigned delivery ${order.orderCode}`,
//           bodyAr: `تم تعيين التسليم ${order.orderCode} لك`,
//           metadata: {
//             deliveryOrderId: order.id
//           },
//         });
//       }
//     } catch (e) {
//       console.error('notify driver error:', e.message || e);
//     }

//     res.json({
//       success: true,
//       message: 'Driver assigned',
//       order
//     });
//   } catch (error) {
//     console.error('assignDriverToOrder error:', error);
//     res.status(500).json({
//       error: 'Failed to assign driver',
//       details: error.message
//     });
//   }
// };

// // ─────────────────────────────────────────────────────────────────────────────
// // GET /api/delivery/orders/driver/:driverId
// // Get delivery orders for a specific driver filtered optional by status
// // ─────────────────────────────────────────────────────────────────────────────
// exports.getDriverOrders = async (req, res) => {
//   try {
//     const {
//       driverId
//     } = req.params;
//     const {
//       status
//     } = req.query;

//     const whereClause = {
//       driverId
//     };
//     if (status) {
//       if (status === 'delivered' || status === 'completed') {
//         whereClause.status = {
//           [Op.in]: ['delivered', 'completed']
//         };
//       } else if (status === 'active') {
//         whereClause.status = {
//           [Op.in]: ['active', 'in_progress']
//         };
//       } else {
//         whereClause.status = status;
//       }
//     }

//     const orders = await DeliveryOrder.findAll({
//       where: whereClause,
//       order: [
//         ['createdAt', 'DESC']
//       ],
//       include: [{
//           model: User,
//           as: 'customer',
//           attributes: ['id', 'name', 'phone', 'city'],
//           required: false
//         },
//         {
//           model: User,
//           as: 'craftsman',
//           attributes: ['id', 'name', 'phone', 'city'],
//           required: false
//         },
//         {
//           model: Product,
//           as: 'product',
//           attributes: ['id', 'titleAr', 'titleEn', 'imageUrl', 'price'],
//           required: false
//         },
//       ],
//     });

//     res.json(orders);
//   } catch (error) {
//     console.error('getDriverOrders error:', error);
//     res.status(500).json({
//       error: 'Failed to fetch driver delivery orders'
//     });
//   }
// };

// // ─────────────────────────────────────────────────────────────────────────────
// // GET /api/delivery/orders/:id
// // Get details of a single delivery order
// // ─────────────────────────────────────────────────────────────────────────────
// exports.getOrderById = async (req, res) => {
//   try {
//     const {
//       id
//     } = req.params;

//     const order = await DeliveryOrder.findByPk(id, {
//       include: [{
//           model: User,
//           as: 'customer',
//           attributes: ['id', 'name', 'phone', 'city', 'email'],
//         },
//         {
//           model: User,
//           as: 'craftsman',
//           attributes: ['id', 'name', 'phone', 'city', 'email'],
//         },
//         {
//           model: Product,
//           as: 'product',
//           attributes: ['id', 'titleAr', 'titleEn', 'imageUrl', 'price'],
//         },
//       ],
//     });

//     if (!order) {
//       return res.status(404).json({
//         message: 'Delivery order not found'
//       });
//     }

//     res.status(200).json(order);
//   } catch (error) {
//     console.error('Error fetching order details:', error);
//     res.status(500).json({
//       message: 'Failed to fetch order details',
//       error: error.message
//     });
//   }
// };




// // ─────────────────────────────────────────────────────────────────────────────
// // POST /api/delivery/orders/:id/accept
// // Accept an available delivery order
// // ─────────────────────────────────────────────────────────────────────────────
// exports.acceptOrder = async (req, res) => {
//   try {
//     const {
//       id
//     } = req.params;
//     const {
//       driverId
//     } = req.body;

//     const order = await DeliveryOrder.findByPk(id);
//     if (!order) {
//       return res.status(404).json({
//         error: 'Delivery order not found'
//       });
//     }

//     if (order.status !== 'available') {
//       return res.status(400).json({
//         error: 'Order is no longer available'
//       });
//     }

//     await order.update({
//       driverId,
//       status: 'active',
//     });

//     res.json({
//       message: 'Order accepted successfully',
//       order
//     });
//   } catch (error) {
//     console.error('acceptOrder error:', error);
//     res.status(500).json({
//       error: 'Failed to accept order'
//     });
//   }
// };

// // ─────────────────────────────────────────────────────────────────────────────
// // PATCH /api/delivery/orders/:id/status
// // Update delivery order status (active, completed, cancelled)
// // ─────────────────────────────────────────────────────────────────────────────
// // PATCH /api/delivery/orders/:id/status
// exports.updateOrderStatus = async (req, res) => {
//   try {
//     const {
//       id
//     } = req.params;
//     const {
//       status,
//       issueType,
//       issueNotes,
//       issuePhotoUrl,
//       cancelReason,
//       cancelledBy
//     } = req.body;

//     const order = await DeliveryOrder.findByPk(id);
//     if (!order) {
//       return res.status(404).json({
//         error: 'Delivery order not found'
//       });
//     }

//     const updates = {
//       status
//     };

//     if (status === 'delivered') {
//       updates.deliveredAt = new Date();
//     } else if (status === 'undelivered' || status === 'returned') {
//       if (issueType) updates.issueType = issueType;
//       if (issueNotes) updates.issueNotes = issueNotes;
//       if (issuePhotoUrl) updates.issuePhotoUrl = issuePhotoUrl;
//     } else if (status === 'cancelled') {
//       // Map cancelReason or fallback to issueNotes/issueType
//       updates.cancelReason = cancelReason || issueNotes || issueType || 'Cancelled by driver';
//       updates.cancelledBy = cancelledBy || 'driver';
//       if (issueType) updates.issueType = issueType;
//       if (issueNotes) updates.issueNotes = issueNotes;
//     }

//     await order.update(updates);

//     res.json({
//       message: `Order status updated to ${status}`,
//       order,
//     });
//   } catch (error) {
//     console.error('updateOrderStatus error:', error);
//     res.status(500).json({
//       error: 'Failed to update order status'
//     });
//   }
// };

// // ─────────────────────────────────────────────────────────────────────────────
// // POST /api/delivery/orders/:id/verify-pin
// // Verify 4-digit PIN code or QR code data to complete delivery and release escrow
// // ─────────────────────────────────────────────────────────────────────────────
// // exports.verifyDeliveryPinOrQR = async (req, res) => {
// //   try {
// //     const {
// //       id
// //     } = req.params;
// //     const {
// //       pin,
// //       qrData
// //     } = req.body;

// //     const order = await DeliveryOrder.findByPk(id);
// //     if (!order) {
// //       return res.status(404).json({
// //         error: 'Delivery order not found'
// //       });
// //     }

// //     const providedPin = String(pin || qrData || '').trim();
// //     const expectedPin = String(order.deliveryPin || '').trim();

// //     // If PIN is provided, verify it matches
// //     if (providedPin !== expectedPin && !providedPin.includes(expectedPin)) {
// //       return res.status(400).json({
// //         error: 'Invalid delivery PIN code or QR data',
// //         success: false,
// //       });
// //     }

// //     // PIN matches! Mark order as delivered / completed
// //     await order.update({
// //       status: 'delivered',
// //       deliveredAt: new Date(),
// //     });

// //     // Check if there is an escrow payment associated and attempt release
// //     let escrowReleased = false;
// //     try {
// //       const payment = await DeliveryPayment.findOne({
// //         where: {
// //           deliveryOrderId: order.id
// //         }
// //       });
// //       if (payment && payment.escrowStatus === 'held') {
// //         await payment.update({
// //           escrowStatus: 'released',
// //           releasedAt: new Date(),
// //         });
// //         escrowReleased = true;
// //       }
// //     } catch (e) {
// //       console.error('Escrow release during delivery verification error:', e.message || e);
// //     }

// //     return res.json({
// //       success: true,
// //       message: 'Delivery verified successfully! Order completed.',
// //       order,
// //       escrowReleased,
// //     });
// //   } catch (error) {
// //     console.error('verifyDeliveryPinOrQR error:', error);
// //     return res.status(500).json({
// //       error: 'Failed to verify delivery PIN',
// //       details: error.message,
// //     });
// //   }
// // };
// // POST /api/delivery/orders/:id/verify-pin
// exports.verifyDeliveryPinOrQR = async (req, res) => {
//   try {
//     const {
//       id
//     } = req.params;
//     const {
//       pin,
//       qrData
//     } = req.body;

//     let order = await DeliveryOrder.findByPk(id);
//     if (!order) {
//       order = await DeliveryOrder.findOne({
//         where: {
//           productOrderId: id
//         }
//       });
//     }
//     if (!order) {
//       return res.status(404).json({
//         error: 'Delivery order not found'
//       });
//     }

//     const providedPin = String(pin || qrData || '').trim();
//     const expectedPin = String(order.deliveryPin || '').trim();

//     if (providedPin !== expectedPin && !providedPin.includes(expectedPin)) {
//       return res.status(400).json({
//         error: 'Invalid delivery PIN code or QR data',
//         success: false,
//       });
//     }

//     // Mark delivery order as delivered
//     await order.update({
//       status: 'delivered',
//       deliveredAt: new Date(),
//     });

//     // Update the product order to 'completed'
//     let productOrderUpdated = false;
//     if (order.productOrderId) {
//       try {
//         const ProductOrder = require('../models/Order');
//         const ReadyMadePayment = require('../models/ReadyMadePayment');

//         await ProductOrder.update({
//           status: 'completed',
//           escrowStatus: 'released',
//           escrowReleasedAt: new Date(),
//         }, {
//           where: {
//             id: order.productOrderId
//           }
//         });
//         productOrderUpdated = true;

//         // Release product escrow
//         const productPayment = await ReadyMadePayment.findOne({
//           where: {
//             orderId: order.productOrderId
//           }
//         });
//         if (productPayment && productPayment.escrowStatus === 'held') {
//           await productPayment.update({
//             escrowStatus: 'released',
//             releasedAt: new Date(),
//           });
//         }
//       } catch (e) {
//         console.error('Failed to update product order:', e.message || e);
//       }
//     }

//     // Check and release delivery order escrow & update driver profile earnings
//     let escrowReleased = false;
//     try {
//       const payment = await DeliveryPayment.findOne({
//         where: {
//           deliveryOrderId: order.id
//         }
//       });
//       if (payment && payment.escrowStatus === 'held') {
//         await payment.update({
//           escrowStatus: 'released',
//           releasedAt: new Date(),
//         });
//         escrowReleased = true;
//       }

//       if (order.driverId && order.earningAmount > 0) {
//         try {
//           const DeliveryProfile = require('../models/DeliveryProfile');
//           const profile = await DeliveryProfile.findOne({
//             where: {
//               driverId: order.driverId
//             }
//           });
//           if (profile) {
//             await profile.update({
//               totalEarnings: Number((parseFloat(profile.totalEarnings || 0) + parseFloat(order.earningAmount || 0)).toFixed(2)),
//               todayEarnings: Number((parseFloat(profile.todayEarnings || 0) + parseFloat(order.earningAmount || 0)).toFixed(2)),
//               totalDeliveries: (profile.totalDeliveries || 0) + 1,
//               todayDeliveries: (profile.todayDeliveries || 0) + 1,
//             });
//           }
//         } catch (pe) {
//           console.error('Failed to update driver profile earnings:', pe.message || pe);
//         }
//       }
//     } catch (e) {
//       console.error('Escrow release error:', e.message || e);
//     }

//     return res.json({
//       success: true,
//       message: 'Delivery verified successfully! Order completed.',
//       order,
//       productOrderUpdated,
//       escrowReleased,
//     });

//     await Notification.create({
//       userId: order.driverId,
//       type: 'delivery_completed',
//       titleEn: 'Delivery completed',
//       titleAr: 'تم إنجاز التوصيل',
//       bodyEn: `You delivered order ${order.orderCode}`,
//       bodyAr: `قمت بتوصيل الطلب ${order.orderCode}`,
//     });
//     await Notification.create({
//       userId: order.customerId,
//       type: 'delivery_completed',
//       titleEn: 'Your order has been delivered',
//       titleAr: 'تم توصيل طلبك',
//       bodyEn: `Order ${order.orderCode} delivered successfully.`,
//       bodyAr: `تم توصيل الطلب ${order.orderCode} بنجاح.`,
//     });

//   } catch (error) {
//     console.error('verifyDeliveryPinOrQR error:', error);
//     return res.status(500).json({
//       error: 'Failed to verify delivery PIN',
//       details: error.message,
//     });
//   }
// };

// // ─────────────────────────────────────────────────────────────────────────────
// // GET /api/delivery/earnings/:driverId
// // Get delivery earnings summary, weekly history, breakdown, and payouts
// // ─────────────────────────────────────────────────────────────────────────────
// exports.getEarnings = async (req, res) => {
//   try {
//     const {
//       driverId
//     } = req.params;

//     let profile = await DeliveryProfile.findOne({
//       where: {
//         driverId
//       }
//     });
//     if (!profile) profile = await DeliveryProfile.create({
//       driverId
//     });

//     // Real balance
//     const balance = parseFloat(profile.totalEarnings || 0);

//     // Real payout history
//     const realPayoutHistory = await Payout.findAll({
//       where: {
//         driverId
//       },
//       order: [
//         ['requestedAt', 'DESC']
//       ],
//     });
//     const payoutHistory = realPayoutHistory.map(p => ({
//       date: p.requestedAt.toISOString().split('T')[0],
//       amount: p.amount,
//       status: p.status,
//     }));

//     // Real weekly earnings (sum of completed deliveries in last 7 days)
//     const sevenDaysAgo = new Date();
//     sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
//     const completedOrders = await DeliveryOrder.findAll({
//       where: {
//         driverId,
//         status: 'delivered',
//         deliveredAt: {
//           [Op.gte]: sevenDaysAgo
//         },
//       },
//     });
//     // Group by day of week (Mon-Sun)
//     const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
//     const weeklyMap = {};
//     days.forEach(d => weeklyMap[d] = 0);
//     completedOrders.forEach(order => {
//       const dayIndex = order.deliveredAt.getDay(); // 0=Sun, 1=Mon, ...
//       const dayName = days[(dayIndex + 6) % 7]; // convert to Mon=0
//       weeklyMap[dayName] += parseFloat(order.earningAmount || 0);
//     });
//     const weeklyEarnings = days.map(day => ({
//       day,
//       amount: weeklyMap[day]
//     }));

//     // Real breakdown – you can compute from actual data, or keep mock
//     const breakdown = [{
//         label: 'الأساسي',
//         labelEn: 'Base Pay',
//         amount: balance * 0.8,
//         color: '#D4A017'
//       },
//       {
//         label: 'المكافآت',
//         labelEn: 'Bonuses',
//         amount: 45,
//         color: '#4CAF50'
//       },
//       {
//         label: 'الخصومات',
//         labelEn: 'Deductions',
//         amount: -15,
//         color: '#F44336'
//       },
//     ];

//     res.json({
//       balance,
//       todayEarnings: parseFloat(profile.todayEarnings || 0),
//       weeklyEarnings,
//       breakdown,
//       payoutHistory,
//       hasStripeAccount: !!profile.connectedAccountId,
//       bankAccount: profile.bankAccount || null, // if you store bank info
//     });
//   } catch (error) {
//     console.error('getEarnings error:', error);
//     res.status(500).json({
//       error: 'Failed to fetch earnings'
//     });
//   }
// };

// // ─────────────────────────────────────────────────────────────────────────────
// // GET /api/delivery/vehicle/:driverId
// // Get driver vehicle details
// // ─────────────────────────────────────────────────────────────────────────────
// exports.getVehicle = async (req, res) => {
//   try {
//     const {
//       driverId
//     } = req.params;

//     let vehicle = await DeliveryVehicle.findOne({
//       where: {
//         driverId
//       }
//     });
//     if (!vehicle) {
//       vehicle = await DeliveryVehicle.create({
//         driverId
//       });
//     }

//     res.json(vehicle);
//   } catch (error) {
//     console.error('getVehicle error:', error);
//     res.status(500).json({
//       error: 'Failed to fetch vehicle information'
//     });
//   }
// };

// // ─────────────────────────────────────────────────────────────────────────────
// // PUT /api/delivery/vehicle/:driverId
// // Update driver vehicle details
// // ─────────────────────────────────────────────────────────────────────────────
// exports.updateVehicle = async (req, res) => {
//   try {
//     const {
//       driverId
//     } = req.params;
//     const {
//       make,
//       model,
//       year,
//       color,
//       colorEn,
//       licensePlate,
//       type,
//       typeEn,
//       capacity,
//       capacityEn,
//       photoUrl,
//     } = req.body;

//     let vehicle = await DeliveryVehicle.findOne({
//       where: {
//         driverId
//       }
//     });
//     if (!vehicle) {
//       vehicle = await DeliveryVehicle.create({
//         driverId,
//         ...req.body
//       });
//     } else {
//       await vehicle.update({
//         ...(make !== undefined && {
//           make
//         }),
//         ...(model !== undefined && {
//           model
//         }),
//         ...(year !== undefined && {
//           year
//         }),
//         ...(color !== undefined && {
//           color
//         }),
//         ...(colorEn !== undefined && {
//           colorEn
//         }),
//         ...(licensePlate !== undefined && {
//           licensePlate
//         }),
//         ...(type !== undefined && {
//           type
//         }),
//         ...(typeEn !== undefined && {
//           typeEn
//         }),
//         ...(capacity !== undefined && {
//           capacity
//         }),
//         ...(capacityEn !== undefined && {
//           capacityEn
//         }),
//         ...(photoUrl !== undefined && {
//           photoUrl
//         }),
//       });
//     }

//     res.json({
//       message: 'Vehicle details updated successfully',
//       vehicle
//     });
//   } catch (error) {
//     console.error('updateVehicle error:', error);
//     res.status(500).json({
//       error: 'Failed to update vehicle details'
//     });
//   }
// };

// // ─────────────────────────────────────────────────────────────────────────────
// // GET /api/delivery/profile/:driverId
// // Get delivery driver profile info
// // ─────────────────────────────────────────────────────────────────────────────
// exports.getProfile = async (req, res) => {
//   try {
//     const {
//       driverId
//     } = req.params;

//     const user = await User.findByPk(driverId, {
//       attributes: ['id', 'name', 'email', 'city', 'profileImage'],
//     });

//     if (!user) {
//       return res.status(404).json({
//         error: 'Driver user not found'
//       });
//     }

//     let profile = await DeliveryProfile.findOne({
//       where: {
//         driverId
//       }
//     });
//     if (!profile) {
//       profile = await DeliveryProfile.create({
//         driverId
//       });
//     }

//     res.json({
//       user,
//       profile,
//     });
//   } catch (error) {
//     console.error('getProfile error:', error);
//     res.status(500).json({
//       error: 'Failed to fetch driver profile'
//     });
//   }
// };

// // ─────────────────────────────────────────────────────────────────────────────
// // PUT /api/delivery/profile/:driverId
// // Update delivery driver profile info
// // ─────────────────────────────────────────────────────────────────────────────
// exports.updateProfile = async (req, res) => {
//   try {
//     const {
//       driverId
//     } = req.params;
//     const {
//       name,
//       city,
//       profileImage
//     } = req.body;

//     const user = await User.findByPk(driverId);
//     if (!user) {
//       return res.status(404).json({
//         error: 'Driver user not found'
//       });
//     }

//     await user.update({
//       ...(name !== undefined && {
//         name
//       }),
//       ...(city !== undefined && {
//         city
//       }),
//       ...(profileImage !== undefined && {
//         profileImage
//       }),
//     });

//     res.json({
//       message: 'Driver profile updated',
//       user
//     });
//   } catch (error) {
//     console.error('updateProfile error:', error);
//     res.status(500).json({
//       error: 'Failed to update driver profile'
//     });
//   }
// };


// // GET /api/delivery/notifications/:userId
// exports.getUserNotifications = async (req, res) => {
//   try {
//     const {
//       userId
//     } = req.params;

//     const notifications = await Notification.findAll({
//       where: {
//         userId
//       },
//       order: [
//         ['createdAt', 'DESC']
//       ],
//     });

//     res.json(notifications);
//   } catch (error) {
//     console.error('getUserNotifications error:', error);
//     res.status(500).json({
//       error: 'Failed to fetch notifications'
//     });
//   }
// };

// // PATCH /api/delivery/notifications/:id/read
// exports.markAsRead = async (req, res) => {
//   try {
//     const {
//       id
//     } = req.params;

//     const notification = await Notification.findByPk(id);
//     if (!notification) {
//       return res.status(404).json({
//         error: 'Notification not found'
//       });
//     }

//     await notification.update({
//       isRead: true
//     });

//     res.json({
//       message: 'Notification marked as read',
//       notification
//     });
//   } catch (error) {
//     console.error('markAsRead error:', error);
//     res.status(500).json({
//       error: 'Failed to update notification status'
//     });
//   }
// };

// // ─────────────────────────────────────────────────────────────────────────────
// // POST /api/delivery/sos
// // Driver triggers emergency SOS alert
// // ─────────────────────────────────────────────────────────────────────────────
// const DeliveryIssue = require('../models/DeliveryIssue');

// exports.triggerSOS = async (req, res) => {
//   try {
//     const {
//       driverId,
//       location,
//       orderId,
//       notes
//     } = req.body;

//     const issue = await DeliveryIssue.create({
//       driverId: driverId || req.user?.id,
//       orderId: orderId || null,
//       issueType: 'sos',
//       description: `Emergency SOS Alert! Location: ${location || 'Unknown Location'}`,
//       status: 'new',
//       reportedBy: 'driver',
//       notes: notes || 'Driver pressed emergency SOS button',
//     });

//     res.status(201).json({
//       message: 'SOS Alert triggered successfully',
//       issue,
//     });
//   } catch (error) {
//     console.error('triggerSOS error:', error);
//     res.status(500).json({
//       error: 'Failed to trigger SOS alert'
//     });
//   }
// };

// // POST /api/delivery/orders
// exports.createDeliveryOrder = async (req, res) => {
//   try {
//     const {
//       orderId, // ready‑made product order ID
//       customOrderId, // NEW: custom order ID
//       productId,
//       pickupAddress,
//       dropoffAddress,
//       customerPhone,
//       pickupPhone,
//       weightKg,
//       isFragile,
//       earningAmount,
//       driverId,
//       dueDate,
//     } = req.body;

//     const craftsmanId = req.user.id;

//     let targetDropoffAddress = dropoffAddress;
//     let targetCustomerPhone = customerPhone;
//     let targetCustomerId = null;
//     let targetCustomOrderId = customOrderId || null;

//     // 1. If ready‑made order ID is provided, fetch product order details
//     if (orderId) {
//       try {
//         const ProductOrder = require('../models/Order');
//         const prodOrder = await ProductOrder.findByPk(orderId);
//         if (prodOrder) {
//           if (!targetDropoffAddress) targetDropoffAddress = prodOrder.shippingAddress;
//           if (!targetCustomerPhone) targetCustomerPhone = prodOrder.customerPhone;
//           targetCustomerId = prodOrder.customerId;
//         }
//       } catch (_) {}
//     }

//     // 2. If custom order ID is provided, fetch custom order request details
//     if (customOrderId) {
//       try {
//         const CustomOrderRequest = require('../models/CustomOrderRequest');
//         const customReq = await CustomOrderRequest.findByPk(customOrderId);
//         if (customReq) {
//           if (!targetDropoffAddress) targetDropoffAddress = customReq.deliveryAddress;
//           if (!targetCustomerPhone) targetCustomerPhone = customReq.customerPhone;
//           targetCustomerId = customReq.customerId;
//           targetCustomOrderId = customOrderId;
//         }
//       } catch (_) {}
//     }

//     if (!pickupAddress || !targetDropoffAddress) {
//       return res.status(400).json({
//         error: 'Pickup and dropoff addresses are required'
//       });
//     }

//     // Generate PIN and QR data
//     const deliveryPin = String(1000 + Math.floor(Math.random() * 9000));
//     const orderCode = 'DEL-' + Date.now().toString(36).toUpperCase();
//     const qrData = `DELIVERY:${orderCode}:${Date.now()}`;

//     const initialStatus = driverId ? 'active' : 'available';

//     // Determine order type
//     let orderType = 'ready_made';
//     if (customOrderId) orderType = 'custom_made';

//     const deliveryOrder = await DeliveryOrder.create({
//       orderCode,
//       customerId: targetCustomerId,
//       craftsmanId,
//       driverId: driverId || null,
//       productId: productId || null,
//       productOrderId: orderId || null,
//       customOrderId: targetCustomOrderId, // store custom order ID
//       orderType,
//       customSpecifications: null,
//       status: initialStatus,
//       pickupAddress,
//       pickupPhone: pickupPhone || '',
//       dropoffAddress: targetDropoffAddress,
//       customerPhone: targetCustomerPhone,
//       earningAmount: earningAmount || 0,
//       weightKg: weightKg || 0,
//       isFragile: isFragile || false,
//       dueAt: dueDate || null,
//       deliveryPin,
//       qrCodeData: qrData,
//     });

//     // After creating deliveryOrder
//     await Notification.create({
//       userId: driverId, // if specific driver, else broadcast
//       type: 'delivery_available',
//       titleEn: 'New delivery available',
//       titleAr: 'توصيل جديد متاح',
//       bodyEn: `Pickup from ${pickupAddress}`,
//       bodyAr: `استلام من ${pickupAddress}`,
//       metadata: {
//         deliveryOrderId: deliveryOrder.id
//       },
//     });

//     // If ready‑made order ID provided, update its status
//     if (orderId) {
//       try {
//         const ProductOrder = require('../models/Order');
//         await ProductOrder.update({
//           status: 'waiting_delivery'
//         }, {
//           where: {
//             id: orderId
//           }
//         });
//       } catch (e) {
//         console.error('Failed to update product order status:', e.message || e);
//       }
//     }

//     // If custom order ID provided, update its status (optional)
//     if (customOrderId) {
//       try {
//         const CustomOrderRequest = require('../models/CustomOrderRequest');
//         await CustomOrderRequest.update({
//           status: 'in_progress' // or 'ready_for_delivery'
//         }, {
//           where: {
//             id: customOrderId
//           }
//         });
//       } catch (e) {
//         console.error('Failed to update custom order status:', e.message || e);
//       }
//     }

//     res.status(201).json({
//       success: true,
//       message: 'Delivery order created successfully',
//       deliveryOrder: {
//         ...deliveryOrder.toJSON(),
//         deliveryPin,
//         qrCodeData: qrData,
//       },
//     });
//   } catch (error) {
//     console.error('createDeliveryOrder error:', error);
//     res.status(500).json({
//       error: 'Failed to create delivery order',
//       details: error.message,
//     });
//   }
// };

// // ─────────────────────────────────────────────────────────────────────────────
// // POST /api/delivery/payout/request
// // Driver requests a payout from available earnings
// // ─────────────────────────────────────────────────────────────────────────────
// exports.requestPayout = async (req, res) => {
//   try {
//     const {
//       driverId,
//       amount
//     } = req.body;
//     if (!driverId || !amount || amount <= 0) {
//       return res.status(400).json({
//         error: 'Invalid driver ID or amount'
//       });
//     }

//     const driver = await User.findByPk(driverId);
//     if (!driver) {
//       return res.status(404).json({
//         error: 'Driver not found'
//       });
//     }

//     // Get driver profile
//     let profile = await DeliveryProfile.findOne({
//       where: {
//         driverId
//       }
//     });
//     if (!profile) {
//       profile = await DeliveryProfile.create({
//         driverId
//       });
//     }

//     const availableBalance = parseFloat(profile.totalEarnings || 0);
//     const requestedAmount = parseFloat(amount);
//     if (requestedAmount > availableBalance) {
//       return res.status(400).json({
//         error: 'Insufficient balance'
//       });
//     }

//     // Check if driver has a Stripe Connect account
//     const connectedAccountId = profile.connectedAccountId;
//     if (!connectedAccountId) {
//       return res.status(400).json({
//         error: 'Driver has not onboarded with Stripe. Please onboard first.',
//         onboardRequired: true,
//       });
//     }

//     // Create Stripe Transfer
//     let transfer;
//     try {
//       const transferAmountInCents = Math.round((requestedAmount / Number(process.env.JOD_PER_USD || 3.1122)) * 100);
//       transfer = await stripe.transfers.create({
//         amount: transferAmountInCents,
//         currency: 'usd',
//         destination: connectedAccountId,
//         description: `Payout to driver ${driverId} for ${requestedAmount} JOD`,
//       });
//     } catch (stripeError) {
//       console.error('[Stripe Transfer Error]', stripeError.message);
//       return res.status(500).json({
//         error: 'Stripe transfer failed',
//         details: stripeError.message,
//       });
//     }

//     // Deduct from profile earnings
//     await profile.update({
//       totalEarnings: availableBalance - requestedAmount,
//     });

//     // Create Payout record
//     const payout = await Payout.create({
//       driverId,
//       amount: requestedAmount,
//       stripeTransferId: transfer.id,
//       status: 'completed',
//       completedAt: new Date(),
//     });

//     // Optionally create a notification
//     await Notification.create({
//       userId: driverId,
//       type: 'payout',
//       titleEn: 'Payout Completed',
//       titleAr: 'تم إتمام السحب',
//       bodyEn: `Successfully transferred ${requestedAmount} JOD to your bank account.`,
//       bodyAr: `تم تحويل ${requestedAmount} دينار إلى حسابك البنكي بنجاح.`,
//     });

//     res.json({
//       success: true,
//       message: 'Payout successful',
//       payout,
//       newBalance: profile.totalEarnings,
//     });
//   } catch (error) {
//     console.error('[requestPayout] ERROR:', error);
//     res.status(500).json({
//       error: 'Failed to process payout',
//       details: error.message,
//     });
//   }
// };
// // POST /api/delivery/orders
// exports.createDeliveryOrder = async (req, res) => {
//   try {
//     const {
//       orderId, // original order ID (could be custom order or product order)
//       productId, // optional product ID
//       pickupAddress,
//       dropoffAddress,
//       customerPhone,
//       pickupPhone,
//       weightKg,
//       isFragile,
//       earningAmount, // delivery fee
//       driverId, // optional driver assignment
//     } = req.body;

//     // The artisan (craftsman) is the logged-in user
//     const craftsmanId = req.user.id;

//     // Validate required fields
//     if (!pickupAddress || !dropoffAddress || !customerPhone) {
//       return res.status(400).json({
//         error: 'Missing required fields'
//       });
//     }

//     // Optionally verify that the artisan is the owner of the original order
//     // For simplicity, we trust the artisan.

//     const orderCode = 'DEL-' + Date.now().toString(36).toUpperCase();

//     const deliveryOrder = await DeliveryOrder.create({
//       orderCode,
//       customerId: null, // will be filled from original order? We can set later.
//       craftsmanId,
//       driverId: driverId || null,
//       productId: productId || null,
//       orderType: orderId ? 'custom_made' : 'ready_made',
//       customSpecifications: null,
//       status: 'available', // drivers can see it
//       pickupAddress,
//       pickupPhone: pickupPhone || '',
//       dropoffAddress,
//       customerPhone,
//       earningAmount: earningAmount || 0,
//       weightKg: weightKg || 0,
//       isFragile: isFragile || false,
//       dueAt: null,
//     });

//     // If we have an orderId, we could link it, but we don't have a direct field.
//     // We can add a 'relatedOrderId' field to DeliveryOrder if needed.

//     res.status(201).json({
//       success: true,
//       message: 'Delivery order created successfully',
//       deliveryOrder,
//     });
//   } catch (error) {
//     console.error('createDeliveryOrder error:', error);
//     res.status(500).json({
//       error: 'Failed to create delivery order',
//       details: error.message,
//     });
//   }
// };

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/delivery/orders/:id/review
// Rate & Review delivery order
// ─────────────────────────────────────────────────────────────────────────────
exports.reviewDeliveryOrder = async (req, res) => {
  try {
    const { id } = req.params;
    const { rating, comment, role } = req.body;

    const dOrder = await DeliveryOrder.findByPk(id);
    if (!dOrder) {
      return res.status(404).json({ error: 'Delivery order not found' });
    }

    const ratingVal = parseInt(rating, 10);
    if (isNaN(ratingVal) || ratingVal < 1 || ratingVal > 5) {
      return res.status(400).json({ error: 'Rating must be an integer between 1 and 5' });
    }

    await dOrder.update({
      rating: ratingVal,
      reviewComment: comment || '',
      reviewedByRole: role || (req.user ? req.user.role : 'customer'),
    });

    // Update Driver Profile Average Rating
    if (dOrder.driverId) {
      const ratedOrders = await DeliveryOrder.findAll({
        where: {
          driverId: dOrder.driverId,
          rating: { [Op.ne]: null },
        },
      });

      if (ratedOrders.length > 0) {
        const avgRating = (
          ratedOrders.reduce((sum, o) => sum + o.rating, 0) / ratedOrders.length
        ).toFixed(1);

        const profile = await DeliveryProfile.findOne({ where: { driverId: dOrder.driverId } });
        if (profile) {
          await profile.update({ rating: parseFloat(avgRating) });
        }
      }
    }

    res.json({
      success: true,
      message: 'Delivery review submitted successfully',
      rating: ratingVal,
    });
  } catch (error) {
    console.error('reviewDeliveryOrder error:', error);
    res.status(500).json({ error: 'Failed to submit delivery review' });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/delivery/orders/:id/report
// Report delivery driver to admin
// ─────────────────────────────────────────────────────────────────────────────
exports.reportDeliveryDriver = async (req, res) => {
  try {
    const { id } = req.params;
    const { reason, notes, reporterRole } = req.body;
    const reporterId = req.user ? req.user.id : req.body.reporterId;

    const dOrder = await DeliveryOrder.findByPk(id);
    if (!dOrder) {
      return res.status(404).json({ error: 'Delivery order not found' });
    }

    const OrderDispute = require('../models/OrderDispute');
    const reportedUserId = dOrder.driverId || dOrder.craftsmanId;
    const repRole = (reporterRole || (req.user ? req.user.role : 'customer')) === 'craftsman' ? 'craftsman' : 'customer';

    const dispute = await OrderDispute.create({
      deliveryOrderId: dOrder.id,
      reporterId: reporterId || dOrder.customerId,
      reporterRole: repRole,
      reportedUserId: reportedUserId || dOrder.craftsmanId,
      driverId: dOrder.driverId || null,
      issueCategory: 'late_delivery',
      description: `[Delivery Driver Report] Reason: ${reason || 'Other'}. Notes: ${notes || ''}`,
      status: 'open',
    });

    await dOrder.update({
      issueType: 'other',
      issueNotes: `Reported by ${repRole}: ${reason} - ${notes || ''}`,
    });

    res.json({
      success: true,
      message: 'Report submitted to admin successfully',
      disputeId: dispute.id,
    });
  } catch (error) {
    console.error('reportDeliveryDriver error:', error);
    res.status(500).json({ error: 'Failed to report delivery driver' });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/delivery/drivers/:driverId/reviews
// Fetch all reviews for a delivery driver
// ─────────────────────────────────────────────────────────────────────────────
exports.getDriverReviews = async (req, res) => {
  try {
    const { driverId } = req.params;

    const ratedOrders = await DeliveryOrder.findAll({
      where: {
        driverId,
        rating: { [Op.ne]: null },
      },
      order: [['deliveredAt', 'DESC'], ['updatedAt', 'DESC']],
      include: [
        { model: User, as: 'customer', attributes: ['id', 'name'], required: false },
        { model: User, as: 'craftsman', attributes: ['id', 'name'], required: false },
      ],
    });

    const reviews = ratedOrders.map((o) => ({
      id: o.id,
      orderCode: o.orderCode,
      rating: o.rating,
      comment: o.reviewComment || '',
      reviewerName: o.reviewedByRole === 'craftsman'
        ? (o.craftsman ? o.craftsman.name : 'Craftsman')
        : (o.customer ? o.customer.name : 'Customer'),
      reviewedByRole: o.reviewedByRole || 'customer',
      date: o.deliveredAt ? o.deliveredAt.toISOString().split('T')[0] : o.updatedAt.toISOString().split('T')[0],
      productName: o.productName || 'Delivery Order',
    }));

    res.json({
      success: true,
      total: reviews.length,
      reviews,
    });
  } catch (error) {
    console.error('getDriverReviews error:', error);
    res.status(500).json({ error: 'Failed to fetch driver reviews' });
  }
};