const Order = require('../models/Order');
const Product = require('../models/Product');
const User = require('../models/User');
const UserInteraction = require('../models/UserInteraction');

// POST /api/orders (Checkout)
exports.createOrder = async (req, res) => {
  const t = await require('../config/database').transaction();
  try {
    const { items, deliveryAddress, paymentMethod } = req.body;
    const customerId = req.user.id;

    if (!items || !Array.isArray(items) || items.length === 0) {
      await t.rollback();
      return res.status(400).json({ error: 'No items provided for checkout' });
    }
    if (!deliveryAddress) {
      await t.rollback();
      return res.status(400).json({ error: 'Delivery address is required' });
    }
    if (!paymentMethod) {
      await t.rollback();
      return res.status(400).json({ error: 'Payment method is required' });
    }

    const createdOrders = [];
    const interactionIdsToDelete = [];

    for (const item of items) {
      const { productId, quantity, interactionId } = item;
      
      const product = await Product.findByPk(productId, { transaction: t });
      if (!product) {
        await t.rollback();
        return res.status(404).json({ error: `Product not found: ${productId}` });
      }

      if (product.isPublic === false || product.isAvailable === false) {
        await t.rollback();
        return res.status(400).json({ error: `Product not available: ${product.nameEn || productId}` });
      }

      const qty = quantity && Number.isInteger(quantity) && quantity > 0 && quantity <= 999 ? quantity : 1;

      if (!interactionId) {
        await t.rollback();
        return res.status(400).json({ error: 'Cart interactionId is required' });
      }

      const cartInteraction = await UserInteraction.findOne({
        where: { id: interactionId, userId: customerId, productId, interactionType: 'cart' },
        transaction: t
      });

      if (!cartInteraction) {
        await t.rollback();
        return res.status(400).json({ error: 'Cart item mismatch or not found' });
      }

      if (cartInteraction.quantity !== qty) {
        await t.rollback();
        return res.status(400).json({ error: 'Cart quantity mismatch' });
      }

      const order = await Order.create({
        customerId,
        craftsmanId: product.craftsmanId,
        productId,
        quantity: qty,
        totalAmount: product.price * qty,
        shippingAddress: deliveryAddress,
        paymentMethod: paymentMethod,
        status: 'pending'
      }, { transaction: t });

      createdOrders.push(order);
      interactionIdsToDelete.push(interactionId);
    }

    if (interactionIdsToDelete.length > 0) {
      await UserInteraction.destroy({
        where: { id: interactionIdsToDelete, userId: customerId },
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
    console.error(error);
    res.status(500).json({ error: 'Failed to create order' });
  }
};

// GET /api/orders/customer
exports.getOrdersByUser = async (req, res) => {
  try {
    const customerId = req.user.id;
    const dbOrders = await Order.findAll({
      where: { customerId },
      include: [
        { model: Product, include: [{ model: User, as: 'Craftsman', attributes: ['name', 'city'] }] },
        { model: User, as: 'craftsman', attributes: ['name', 'city'] }
      ],
      order: [['createdAt', 'DESC']]
    });
    
    const formattedOrders = dbOrders.map(o => ({
      id: o.id,
      status: o.status,
      createdAt: o.createdAt,
      totalAmount: o.totalAmount,
      items: [
        {
          productId: o.productId,
          productName: o.Product ? (o.Product.titleEn || o.Product.titleAr) : 'Unknown',
          imageUrl: o.Product ? o.Product.imageUrl : '',
          quantity: o.quantity,
          unitPrice: o.Product ? o.Product.price : 0,
          craftsmanName: o.craftsman ? o.craftsman.name : (o.Product && o.Product.Craftsman ? o.Product.Craftsman.name : 'Unknown')
        }
      ]
    }));

    res.json({ success: true, orders: formattedOrders });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to fetch orders' });
  }
};

// GET /api/orders/craftsman/:craftsmanId
exports.getOrdersByCraftsman = async (req, res) => {
  try {
    const { craftsmanId } = req.params;
    
    if (req.user.role !== 'admin' && req.user.id !== craftsmanId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const dbOrders = await Order.findAll({
      where: { craftsmanId },
      include: [
        { model: Product },
        { model: User, as: 'customer', attributes: ['name', 'email', 'city'] },
        { model: User, as: 'craftsman', attributes: ['name', 'city'] }
      ],
      order: [['createdAt', 'DESC']]
    });
    
    const formattedOrders = dbOrders.map(o => ({
      id: o.id,
      status: o.status,
      createdAt: o.createdAt,
      totalAmount: o.totalAmount,
      customerName: o.customer ? o.customer.name : 'Unknown',
      shippingAddress: o.shippingAddress,
      items: [
        {
          productId: o.productId,
          productName: o.Product ? (o.Product.titleEn || o.Product.titleAr) : 'Unknown',
          imageUrl: o.Product ? o.Product.imageUrl : '',
          quantity: o.quantity,
          unitPrice: o.Product ? o.Product.price : 0,
          craftsmanName: o.craftsman ? o.craftsman.name : 'Unknown'
        }
      ]
    }));

    res.json({ success: true, orders: formattedOrders });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to fetch craftsman orders' });
  }
};

// PATCH /api/orders/:id/status
exports.updateOrderStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    const validStatuses = ['pending', 'accepted', 'in_progress', 'completed', 'cancelled'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ error: `Invalid status. Must be one of: ${validStatuses.join(', ')}` });
    }

    const order = await Order.findByPk(id);
    if (!order) return res.status(404).json({ error: 'Order not found' });

    const isAdmin = req.user.role === 'admin';
    const isCraftsman = order.craftsmanId === req.user.id;
    const isOwningCustomerCancelling = order.customerId === req.user.id && status === 'cancelled' && order.status === 'pending';

    if (!isAdmin && !isCraftsman && !isOwningCustomerCancelling) {
      return res.status(403).json({ error: 'Forbidden: not your order to manage or you cannot change to this status' });
    }

    order.status = status;
    await order.save();
    res.json({ message: `Order status updated to '${status}'`, order });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to update order status' });
  }
};

// GET /api/orders/:id
exports.getOrderById = async (req, res) => {
  try {
    const order = await Order.findByPk(req.params.id, {
      include: [
        { model: Product, include: [{ model: User, as: 'Craftsman', attributes: ['name', 'city'] }] },
        { model: User, as: 'customer', attributes: ['name', 'email'] },
        { model: User, as: 'craftsman', attributes: ['name', 'city'] }
      ]
    });
    if (!order) return res.status(404).json({ error: 'Order not found' });

    if (req.user.role !== 'admin' && req.user.id !== order.customerId && req.user.id !== order.craftsmanId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const formattedOrder = {
      id: order.id,
      status: order.status,
      createdAt: order.createdAt,
      totalAmount: order.totalAmount,
      shippingAddress: order.shippingAddress,
      customer: order.customer,
      items: [
        {
          productId: order.productId,
          productName: order.Product ? (order.Product.titleEn || order.Product.titleAr) : 'Unknown',
          imageUrl: order.Product ? order.Product.imageUrl : '',
          quantity: order.quantity,
          unitPrice: order.Product ? order.Product.price : 0,
          craftsmanName: order.craftsman ? order.craftsman.name : (order.Product && order.Product.Craftsman ? order.Product.Craftsman.name : 'Unknown')
        }
      ]
    };

    res.json({ success: true, order: formattedOrder });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to fetch order' });
  }
};
