const Order = require('../models/Order');
const Product = require('../models/Product');
const User = require('../models/User');
const UserInteraction = require('../models/UserInteraction');
const ReadyMadePayment = require('../models/ReadyMadePayment');
const sequelize = Order.sequelize;

const DeliveryOrder = require('../models/DeliveryOrder');

// ── Helper to format a raw Order row into the standard API shape ──────────
function formatOrder(o) {
  const productName = o.Product
    ? (o.Product.titleEn || o.Product.titleAr || 'Unknown')
    : 'Unknown';

  const dOrder = o.DeliveryOrder || o.deliveryOrder || o.delivery;
  const deliveryPin = dOrder ? dOrder.deliveryPin : (o.deliveryPin || null);

  return {
    id: o.id,

    // نرجع ID الحرفي الحقيقي مع بيانات الطلب
    craftsmanId:
      o.craftsmanId ||
      (o.craftsman ? o.craftsman.id : null) ||
      (o.Product && o.Product.Craftsman
        ? o.Product.Craftsman.id
        : null),

    status: o.status,
    paymentStatus: o.paymentStatus,
    escrowStatus: o.escrowStatus,
    createdAt: o.createdAt,
    totalAmount: parseFloat(o.totalAmount) || 0,
    shippingAddress: o.shippingAddress || '',
    customerPhone: o.customerPhone || (o.customer ? o.customer.phone : '') || '',
    paymentMethod: o.paymentMethod || '',

    customerName: o.customer
      ? o.customer.name
      : 'Unknown',

    deliveryPin: deliveryPin,
    deliveryOrder: dOrder ? {
      id: dOrder.id,
      orderCode: dOrder.orderCode,
      deliveryPin: dOrder.deliveryPin,
      status: dOrder.status,
      driverId: dOrder.driverId,
    } : null,

    items: [
      {
        productId: o.productId,
        productName,

        imageUrl: o.Product
          ? (o.Product.imageUrl || '')
          : '',

        quantity: o.quantity,

        unitPrice:
          parseFloat(o.agreedUnitPrice) ||
          (o.Product ? (parseFloat(o.Product.price) || 0) : 0),

        craftsmanId:
          o.craftsmanId ||
          (o.craftsman ? o.craftsman.id : null) ||
          (o.Product && o.Product.Craftsman
            ? o.Product.Craftsman.id
            : null),

        craftsmanName: o.craftsman
          ? o.craftsman.name
          : (
              o.Product && o.Product.Craftsman
                ? o.Product.Craftsman.name
                : 'Unknown'
            ),
      }
    ]
  };
}

// ── Standard includes used for fetching orders ────────────────────────────
const ORDER_INCLUDES = [
  {
    model: Product,
    required: false,
    include: [
      {
        model: User,
        as: 'Craftsman',
        attributes: ['id', 'name', 'city'],
        required: false,
      }
    ]
  },

  {
    model: User,
    as: 'customer',
    attributes: ['id', 'name', 'email', 'city'],
    required: false,
  },

  {
    model: User,
    as: 'craftsman',
    attributes: ['id', 'name', 'city'],
    required: false,
  },

  {
    model: DeliveryOrder,
    as: 'DeliveryOrder',
    required: false,
  }
];

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/orders
// ─────────────────────────────────────────────────────────────────────────────
exports.createOrder = async (req, res) => {
  const t = await require('../config/database').transaction();

  try {
    const {
      items,
      deliveryAddress,
      customerPhone,
      paymentMethod
    } = req.body;

    const customerId = req.user.id;

    if (
      !items ||
      !Array.isArray(items) ||
      items.length === 0
    ) {
      await t.rollback();

      return res.status(400).json({
        error: 'No items provided for checkout'
      });
    }

    const createdOrders = [];
    const interactionIdsToDelete = [];

    for (const item of items) {
      const {
        productId,
        quantity,
        interactionId
      } = item;

      const product = await Product.findByPk(
        productId,
        {
          transaction: t
        }
      );

      if (!product) {
        await t.rollback();

        return res.status(404).json({
          error: `Product not found: ${productId}`
        });
      }

      if (
        product.isPublic === false ||
        product.isAvailable === false
      ) {
        await t.rollback();

        return res.status(400).json({
          error: `Product not available: ${productId}`
        });
      }

      const qty =
        quantity &&
        Number.isInteger(quantity) &&
        quantity > 0 &&
        quantity <= 999
          ? quantity
          : 1;

      const isBuyNow = item.buyNow === true;

      if (!interactionId && !isBuyNow) {
        await t.rollback();

        return res.status(400).json({
          error: 'Cart interactionId is required'
        });
      }

      const cartInteraction = isBuyNow
        ? null
        : await UserInteraction.findOne({
            where: {
              id: interactionId,
              userId: customerId,
              productId,
              interactionType: 'cart'
            },

            transaction: t
          });

      if (!isBuyNow && !cartInteraction) {
        await t.rollback();

        return res.status(400).json({
          error: 'Cart item mismatch or not found'
        });
      }

      if (!isBuyNow && cartInteraction.quantity !== qty) {
        await t.rollback();

        return res.status(400).json({
          error: 'Cart quantity mismatch'
        });
      }

      const order = await Order.create(
        {
          customerId,

          // ID الحرفي الحقيقي مأخوذ من المنتج
          craftsmanId: product.craftsmanId,

          productId,
          quantity: qty,

          agreedUnitPrice: product.price,
          totalAmount: product.price * qty,

          shippingAddress: deliveryAddress || '',
          customerPhone: customerPhone || null,
          paymentMethod: paymentMethod || 'card',

          status: 'pending_artisan',
          paymentStatus: 'unpaid',
          escrowStatus: 'none'
        },

        {
          transaction: t
        }
      );

      createdOrders.push(order);

      if (interactionId) {
        interactionIdsToDelete.push(interactionId);
      }
    }

    if (interactionIdsToDelete.length > 0) {
      await UserInteraction.destroy({
        where: {
          id: interactionIdsToDelete,
          userId: customerId
        },

        transaction: t
      });
    }

    await t.commit();

    res.status(201).json({
      success: true,
      message: 'Orders placed successfully',
      orders: createdOrders
    });

  } catch (error) {
    await t.rollback();

    console.error(
      '[orderController] createOrder error:',
      error.message
    );

    res.status(500).json({
      error: 'Failed to create order'
    });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/orders/customer
// ─────────────────────────────────────────────────────────────────────────────
exports.getOrdersByUser = async (req, res) => {
  try {
    const customerId = req.user.id;

    const dbOrders = await Order.findAll({
      where: {
        customerId
      },

      include: ORDER_INCLUDES,

      order: [
        ['createdAt', 'DESC']
      ]
    });

    res.json({
      success: true,
      orders: dbOrders.map(formatOrder)
    });

  } catch (error) {
    console.error(
      '[orderController] getOrdersByUser error:',
      error.message
    );

    res.status(500).json({
      error: 'Failed to fetch orders'
    });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/orders/artisan
// ─────────────────────────────────────────────────────────────────────────────
exports.getOrdersForCurrentArtisan = async (req, res) => {
  try {
    const craftsmanId = req.user.id;

    const dbOrders = await Order.findAll({
      where: {
        craftsmanId
      },

      include: ORDER_INCLUDES,

      order: [
        ['createdAt', 'DESC']
      ]
    });

    res.json({
      success: true,
      orders: dbOrders.map(formatOrder)
    });

  } catch (error) {
    console.error(
      '[orderController] getOrdersForCurrentArtisan error:',
      error.message
    );

    res.status(500).json({
      error: 'Failed to fetch artisan orders'
    });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/orders/craftsman/:craftsmanId
// ─────────────────────────────────────────────────────────────────────────────
exports.getOrdersByCraftsman = async (req, res) => {
  try {
    const {
      craftsmanId
    } = req.params;

    const Role = require('../models/Role');

    const requestingUser = await User.findByPk(
      req.user.id,
      {
        include: [
          {
            model: Role,
            attributes: ['name']
          }
        ]
      }
    );

    const userRoles =
      requestingUser &&
      requestingUser.Roles
        ? requestingUser.Roles.map(r => r.name)
        : [];

    const isAdmin = userRoles.includes('admin');

    if (
      !isAdmin &&
      req.user.id !== craftsmanId
    ) {
      return res.status(403).json({
        error: 'Forbidden'
      });
    }

    const dbOrders = await Order.findAll({
      where: {
        craftsmanId
      },

      include: ORDER_INCLUDES,

      order: [
        ['createdAt', 'DESC']
      ]
    });

    res.json({
      success: true,
      orders: dbOrders.map(formatOrder)
    });

  } catch (error) {
    console.error(
      '[orderController] getOrdersByCraftsman error:',
      error.message
    );

    res.status(500).json({
      error: 'Failed to fetch craftsman orders'
    });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/orders/:id/status
// ─────────────────────────────────────────────────────────────────────────────
exports.updateOrderStatus = async (req, res) => {
  try {
    const {
      id
    } = req.params;

    const {
      status
    } = req.body;

    const validStatuses = [
      'pending',
      'pending_artisan',
      'pending_customer',
      'accepted',
      'in_progress',
      'completed',
      'ready',
      'ready_for_delivery',
      'awaiting_payment',
      'cancelled'
    ];

    if (!validStatuses.includes(status)) {
      return res.status(400).json({
        error:
          `Invalid status. Must be one of: ${validStatuses.join(', ')}`
      });
    }

    const order = await Order.findByPk(id);

    if (!order) {
      return res.status(404).json({
        error: 'Order not found'
      });
    }

    const Role = require('../models/Role');

    const requestingUser = await User.findByPk(
      req.user.id,
      {
        include: [
          {
            model: Role,
            attributes: ['name']
          }
        ]
      }
    );

    const userRoles =
      requestingUser &&
      requestingUser.Roles
        ? requestingUser.Roles.map(r => r.name)
        : [];

    const isAdmin = userRoles.includes('admin');

    const isCraftsman =
      order.craftsmanId === req.user.id;

    const isOwningCustomerCancelling =
      order.customerId === req.user.id &&
      status === 'cancelled' &&
      (order.status === 'pending' || order.status === 'pending_artisan' || order.status === 'pending_customer');

    const isCustomerConfirmingDelivery =
      order.customerId === req.user.id &&
      status === 'completed' &&
      (order.status === 'ready' || order.status === 'ready_for_delivery' || order.status === 'in_progress');

    const craftsmanTransitions = {
      pending: ['accepted', 'pending_customer', 'cancelled'],
      pending_artisan: ['accepted', 'pending_customer', 'cancelled'],
      pending_customer: ['accepted', 'in_progress', 'cancelled'],
      accepted: ['in_progress', 'ready_for_delivery', 'cancelled'],
      in_progress: ['ready', 'ready_for_delivery', 'completed'],
    };

    const isValidCraftsmanTransition =
      isCraftsman &&
      (craftsmanTransitions[order.status] || []).includes(status);

    if (
      !isAdmin &&
      !isValidCraftsmanTransition &&
      !isOwningCustomerCancelling &&
      !isCustomerConfirmingDelivery
    ) {
      return res.status(403).json({
        error: 'Forbidden: not your order to manage'
      });
    }

    if (
      status === 'cancelled' &&
      order.paymentStatus === 'paid'
    ) {
      const productPaymentController =
        require('./productPaymentController');

      await productPaymentController.refundOrderPayment(
        order.id,
        `Order cancelled by ${req.user.id}`
      );
    }

    const isCompleting = status === 'completed' || status === 'delivered';

    await sequelize.transaction(async (dbTransaction) => {
      await order.update(
        { status },
        { transaction: dbTransaction }
      );
    });

    if (isCompleting) {
      const { releaseEscrowAndDistributeShares } = require('../utils/escrowHelper');
      await releaseEscrowAndDistributeShares({ orderId: order.id });
    }

    res.json({
      success: true,
      message: `Order status updated to '${status}'`,
      order
    });

  } catch (error) {
    console.error(
      '[orderController] updateOrderStatus error:',
      error.message
    );

    res.status(error.status || 500).json({
      error: 'Failed to update order status'
    });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/orders/:id
// ─────────────────────────────────────────────────────────────────────────────
exports.getOrderById = async (req, res) => {
  try {
    const order = await Order.findByPk(
      req.params.id,
      {
        include: ORDER_INCLUDES
      }
    );

    if (!order) {
      return res.status(404).json({
        error: 'Order not found'
      });
    }

    const Role = require('../models/Role');

    const requestingUser = await User.findByPk(
      req.user.id,
      {
        include: [
          {
            model: Role,
            attributes: ['name']
          }
        ]
      }
    );

    const userRoles =
      requestingUser &&
      requestingUser.Roles
        ? requestingUser.Roles.map(r => r.name)
        : [];

    const isAdmin = userRoles.includes('admin');

    if (
      !isAdmin &&
      req.user.id !== order.customerId &&
      req.user.id !== order.craftsmanId
    ) {
      return res.status(403).json({
        error: 'Forbidden'
      });
    }

    res.json({
      success: true,
      order: formatOrder(order)
    });

  } catch (error) {
    console.error(
      '[orderController] getOrderById error:',
      error.message
    );

    res.status(500).json({
      error: 'Failed to fetch order'
    });
  }
};

exports.deleteOrder = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;
    const order = await Order.findByPk(id);
    if (!order) {
      return res.status(404).json({ error: 'Order not found' });
    }
    if (order.customerId !== userId && order.craftsmanId !== userId) {
      return res.status(403).json({ error: 'Not authorized to delete this order' });
    }
    await order.destroy();
    return res.json({ success: true, message: 'Order deleted successfully' });
  } catch (error) {
    console.error('[orderController] deleteOrder error:', error);
    return res.status(500).json({ error: 'Failed to delete order' });
  }
};