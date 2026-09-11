const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');
const User = require('./User');
const Order = require('./Order');
const CustomOrderRequest = require('./CustomOrderRequest');
const HireRequest = require('./HireRequest');
const DeliveryOrder = require('./DeliveryOrder');

const OrderDispute = sequelize.define('OrderDispute', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  // Links to any order type – nullable, only one will be set
  orderId: {
    type: DataTypes.UUID,
    allowNull: true,
    references: { model: Order, key: 'id' },
  },
  customOrderRequestId: {
    type: DataTypes.UUID,
    allowNull: true,
    references: { model: CustomOrderRequest, key: 'id' },
  },
  hireRequestId: {
    type: DataTypes.UUID,
    allowNull: true,
    references: { model: HireRequest, key: 'id' },
  },
  deliveryOrderId: {
    type: DataTypes.UUID,
    allowNull: true,
    references: { model: DeliveryOrder, key: 'id' },
  },
  // Who is reporting?
  reporterId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: { model: User, key: 'id' },
  },
  reporterRole: {
    type: DataTypes.ENUM('customer', 'craftsman'),
    allowNull: false,
  },
  // Who is being reported?
  reportedUserId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: { model: User, key: 'id' },
  },
  // Optional driver involvement
  driverId: {
    type: DataTypes.UUID,
    allowNull: true,
    references: { model: User, key: 'id' },
  },
  issueCategory: {
    type: DataTypes.ENUM(
      'damaged_in_transit',
      'wrong_item',
      'quality_issue',
      'customer_unresponsive',
      'delivery_fault',
      'other'
    ),
    allowNull: false,
    defaultValue: 'other',
  },
  description: {
    type: DataTypes.TEXT,
    allowNull: false,
  },
  photoUrl: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  requestedAction: {
    type: DataTypes.ENUM('refund', 'release', 'driver_penalty', 'none'),
    allowNull: false,
    defaultValue: 'none',
  },
  adminStatus: {
    type: DataTypes.ENUM('pending', 'under_review', 'resolved_refunded', 'resolved_released', 'dismissed'),
    allowNull: false,
    defaultValue: 'pending',
  },
  adminNotes: {
    type: DataTypes.TEXT,
    allowNull: true,
  },
  resolutionType: {
    type: DataTypes.ENUM('customer_refund', 'artisan_release', 'driver_penalty', 'no_action'),
    allowNull: true,
  },
  createdAt: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW,
  },
  updatedAt: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW,
  },
});

// Associations
OrderDispute.belongsTo(User, { foreignKey: 'reporterId', as: 'reporter' });
OrderDispute.belongsTo(User, { foreignKey: 'reportedUserId', as: 'reportedUser' });
OrderDispute.belongsTo(User, { foreignKey: 'driverId', as: 'driver' });
User.hasMany(OrderDispute, { foreignKey: 'reporterId', as: 'reportedDisputes' });
User.hasMany(OrderDispute, { foreignKey: 'reportedUserId', as: 'receivedDisputes' });
Order.hasMany(OrderDispute, { foreignKey: 'orderId' });
CustomOrderRequest.hasMany(OrderDispute, { foreignKey: 'customOrderRequestId' });
HireRequest.hasMany(OrderDispute, { foreignKey: 'hireRequestId' });
DeliveryOrder.hasMany(OrderDispute, { foreignKey: 'deliveryOrderId' });

module.exports = OrderDispute;
