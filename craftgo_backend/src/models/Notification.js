const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');
const User = require('./User');

const Notification = sequelize.define('Notification', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },

  userId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: {
      model: User,
      key: 'id',
    },
  },

  type: {
    type: DataTypes.STRING,
    allowNull: false,
  },

  titleAr: {
    type: DataTypes.STRING,
    allowNull: false,
  },

  titleEn: {
    type: DataTypes.STRING,
    allowNull: false,
  },

  bodyAr: {
    type: DataTypes.TEXT,
    allowNull: false,
  },

  bodyEn: {
    type: DataTypes.TEXT,
    allowNull: false,
  },

  isRead: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
  },

  metadata: {
    type: DataTypes.JSON,
    allowNull: true,
  },
});

User.hasMany(Notification, {
  foreignKey: 'userId',
  as: 'notifications',
});

Notification.belongsTo(User, {
  foreignKey: 'userId',
  as: 'user',
});

module.exports = Notification;