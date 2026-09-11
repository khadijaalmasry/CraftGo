const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');
const User = require('./User');
const DeliveryOrder = require('./DeliveryOrder');

const DeliveryIssue = sequelize.define('DeliveryIssue', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  orderId: {
    type: DataTypes.UUID,
    allowNull: true,
    references: { model: DeliveryOrder, key: 'id' },
  },
  driverId: {
    type: DataTypes.UUID,
    allowNull: true,
    references: { model: User, key: 'id' },
  },
  issueType: {
    type: DataTypes.ENUM('fraud', 'sos', 'complaint', 'undelivered'),
    allowNull: false,
    defaultValue: 'complaint',
  },
  description: {
    type: DataTypes.TEXT,
    allowNull: false,
  },
  status: {
    type: DataTypes.ENUM('new', 'in_progress', 'resolved', 'dismissed'),
    defaultValue: 'new',
  },
  reportedBy: {
    type: DataTypes.STRING,
    defaultValue: 'system',
  },
  notes: {
    type: DataTypes.TEXT,
    allowNull: true,
  },
  resolvedAt: {
    type: DataTypes.DATE,
    allowNull: true,
  },
});

DeliveryIssue.belongsTo(User, { as: 'driver', foreignKey: 'driverId' });
DeliveryIssue.belongsTo(DeliveryOrder, { as: 'order', foreignKey: 'orderId' });
User.hasMany(DeliveryIssue, { as: 'issues', foreignKey: 'driverId' });
DeliveryOrder.hasMany(DeliveryIssue, { as: 'issues', foreignKey: 'orderId' });

module.exports = DeliveryIssue;
