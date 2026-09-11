const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');
const User = require('./User');

const ReadyMadePayment = sequelize.define('ReadyMadePayment', {
  id: { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
  orderId: { type: DataTypes.UUID, allowNull: false, unique: true },
  customerId: { type: DataTypes.UUID, allowNull: false, references: { model: User, key: 'id' } },
  artisanId: { type: DataTypes.UUID, allowNull: false, references: { model: User, key: 'id' } },
  currency: { type: DataTypes.STRING(3), allowNull: false, defaultValue: 'JOD' },
  grossAmount: { type: DataTypes.DECIMAL(12, 3), allowNull: false },
  adminCommissionRate: { type: DataTypes.DECIMAL(5, 2), allowNull: false, defaultValue: 10 },
  adminCommission: { type: DataTypes.DECIMAL(12, 3), allowNull: false },
  artisanAmount: { type: DataTypes.DECIMAL(12, 3), allowNull: false },
  stripePaymentIntentId: { type: DataTypes.STRING, allowNull: true },
  stripeCheckoutSessionId: { type: DataTypes.STRING, allowNull: true },
  paymentStatus: { type: DataTypes.ENUM('created', 'processing', 'succeeded', 'failed', 'refunded'), defaultValue: 'created' },
  escrowStatus: { type: DataTypes.ENUM('unpaid', 'held', 'released', 'refunded'), defaultValue: 'unpaid' },
  paidAt: { type: DataTypes.DATE, allowNull: true },
  releasedAt: { type: DataTypes.DATE, allowNull: true },
});

module.exports = ReadyMadePayment;
