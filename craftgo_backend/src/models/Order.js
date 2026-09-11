const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');
const User = require('./User');
const Product = require('./Product');

const Order = sequelize.define('Order', {
  id: { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
  customerId: { type: DataTypes.UUID, allowNull: false, references: { model: User, key: 'id' } },
  craftsmanId: { type: DataTypes.UUID, allowNull: false, references: { model: User, key: 'id' } },
  productId: { type: DataTypes.UUID, allowNull: false, references: { model: Product, key: 'id' } },
  offerId: { type: DataTypes.UUID, allowNull: true },
  status: {
    type: DataTypes.ENUM('awaiting_payment', 'pending', 'accepted', 'in_progress', 'ready', 'completed', 'cancelled'),
    defaultValue: 'awaiting_payment',
  },
  totalAmount: { type: DataTypes.DECIMAL(10, 2), allowNull: false },
  agreedUnitPrice: { type: DataTypes.DECIMAL(10, 2), allowNull: false },
  shippingAddress: { type: DataTypes.STRING, allowNull: false },
  customerPhone: { type: DataTypes.STRING, allowNull: true },
  quantity: { type: DataTypes.INTEGER, allowNull: false, defaultValue: 1 },
  paymentMethod: { type: DataTypes.STRING },
  paymentStatus: { type: DataTypes.ENUM('unpaid', 'processing', 'paid', 'failed', 'refunded'), defaultValue: 'unpaid' },
  escrowStatus: { type: DataTypes.ENUM('none', 'held', 'released', 'refunded'), defaultValue: 'none' },
  stripeCheckoutSessionId: { type: DataTypes.STRING, allowNull: true },
  paidAt: { type: DataTypes.DATE, allowNull: true },
  escrowReleasedAt: { type: DataTypes.DATE, allowNull: true },
});

User.hasMany(Order, { foreignKey: 'customerId', as: 'customerOrders' });
Order.belongsTo(User, { foreignKey: 'customerId', as: 'customer' });
User.hasMany(Order, { foreignKey: 'craftsmanId', as: 'craftsmanOrders' });
Order.belongsTo(User, { foreignKey: 'craftsmanId', as: 'craftsman' });
Product.hasMany(Order, { foreignKey: 'productId' });
Order.belongsTo(Product, { foreignKey: 'productId' });

const DeliveryOrder = require('./DeliveryOrder');
Order.hasOne(DeliveryOrder, { foreignKey: 'productOrderId', as: 'DeliveryOrder' });
DeliveryOrder.belongsTo(Order, { foreignKey: 'productOrderId', as: 'Order' });

module.exports = Order;
