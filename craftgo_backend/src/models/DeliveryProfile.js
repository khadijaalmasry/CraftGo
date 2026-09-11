const {
  DataTypes
} = require('sequelize');
const sequelize = require('../config/database');
const User = require('./User');

const DeliveryProfile = sequelize.define('DeliveryProfile', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  driverId: {
    type: DataTypes.UUID,
    allowNull: false,
    unique: true,
    references: {
      model: User,
      key: 'id'
    },
  },
  isOnline: {
    type: DataTypes.BOOLEAN,
    defaultValue: true,
  },
  rating: {
    type: DataTypes.FLOAT,
    defaultValue: 4.9,
  },
  totalDeliveries: {
    type: DataTypes.INTEGER,
    defaultValue: 0,
  },
  todayDeliveries: {
    type: DataTypes.INTEGER,
    defaultValue: 0,
  },
  todayEarnings: {
    type: DataTypes.DECIMAL(10, 2),
    defaultValue: 0.00,
  },
  totalEarnings: {
    type: DataTypes.DECIMAL(10, 2),
    defaultValue: 0.00,
  },
  isVerified: {
    type: DataTypes.BOOLEAN,
    defaultValue: true,
  },
  verificationStatus: {
    type: DataTypes.ENUM('pending', 'verified', 'rejected'),
    defaultValue: 'verified',
  },
  isSuspended: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
  },
  idCardUrl: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  facePhotoUrl: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  permitUrl: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  connectedAccountId: {
    type: DataTypes.STRING,
    allowNull: true,
  },
});

User.hasOne(DeliveryProfile, {
  foreignKey: 'driverId',
  as: 'deliveryProfile'
});
DeliveryProfile.belongsTo(User, {
  foreignKey: 'driverId',
  as: 'driver'
});

module.exports = DeliveryProfile;