const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');
const User = require('./User');
const HireRequest = require('./HireRequest');

const PaymentTransaction = sequelize.define('PaymentTransaction', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  hireRequestId: {
    type: DataTypes.UUID,
    allowNull: false,
    unique: true,
    references: { model: HireRequest, key: 'id' },
  },
  customerId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: { model: User, key: 'id' },
  },
  artisanId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: { model: User, key: 'id' },
  },
  currency: {
    type: DataTypes.STRING(3),
    allowNull: false,
    defaultValue: 'JOD',
  },
  grossAmount: { type: DataTypes.DECIMAL(12, 3), allowNull: false },
  adminCommissionRate: {
    type: DataTypes.DECIMAL(5, 2),
    allowNull: false,
    defaultValue: 10,
  },
  adminCommission: { type: DataTypes.DECIMAL(12, 3), allowNull: false },
  artisanAmount: { type: DataTypes.DECIMAL(12, 3), allowNull: false },
  stripePaymentIntentId: { type: DataTypes.STRING, allowNull: true, unique: true },
  paymentStatus: {
    type: DataTypes.ENUM('created', 'processing', 'succeeded', 'failed', 'refunded'),
    allowNull: false,
    defaultValue: 'created',
  },
  escrowStatus: {
    type: DataTypes.ENUM('unpaid', 'held', 'released', 'refunded'),
    allowNull: false,
    defaultValue: 'unpaid',
  },
  paidAt: { type: DataTypes.DATE, allowNull: true },
  releasedAt: { type: DataTypes.DATE, allowNull: true },
  failureMessage: { type: DataTypes.TEXT, allowNull: true },
});

HireRequest.hasOne(PaymentTransaction, {
  foreignKey: 'hireRequestId',
  as: 'payment',
});
PaymentTransaction.belongsTo(HireRequest, {
  foreignKey: 'hireRequestId',
  as: 'hireRequest',
});
PaymentTransaction.belongsTo(User, { foreignKey: 'customerId', as: 'customer' });
PaymentTransaction.belongsTo(User, { foreignKey: 'artisanId', as: 'artisan' });

module.exports = PaymentTransaction;
